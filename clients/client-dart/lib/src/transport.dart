import 'dart:async';

import 'package:logging/logging.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'binary_decoder.dart';
import 'channel_message.dart';
import 'json_decoder.dart';
import 'message_decoder.dart';
import 'status_codes.dart';

class Transport {
  final _log = Logger('Transport');
  final IOWebSocketChannel _webSocketCh;
  final StreamController<ChannelMessage> _localStream;
  final int _heartbeatIntervalMs;
  final Function _signalSocketClose;
  final Function _signalSocketError;

  String? pendingHeartbeatRef;
  int _ref = 0;
  Timer? _heartbeatTimer;

  MessageDecoder? msgDecoder;

  Transport(
    this._webSocketCh,
    this._localStream,
    this._signalSocketClose,
    this._signalSocketError,
    this._heartbeatIntervalMs,
  );

  bool isOpen() {
    return _webSocketCh.innerWebSocket != null && readyState() == 1;
  }

  int readyState() {
    var readyState = 0;

    if (_webSocketCh.innerWebSocket != null) {
      readyState = _webSocketCh.innerWebSocket!.readyState;
    }

    return readyState;
  }

  String? getProtocol() {
    return _webSocketCh.protocol;
  }

  Future<dynamic> close(int code, String reason) async {
    if (_heartbeatTimer != null) {
      _heartbeatTimer?.cancel();
    }

    return await close(code, reason);
  }

  int? getCloseCode() {
    return _webSocketCh.closeCode;
  }

  StreamSubscription<dynamic> subscribe({required bool cancelOnErrorFlag}) {
    return _webSocketCh.stream.listen((data) {
      _onData(data);
    }, onError: (error, stackTrace) {
      _onSocketError(error, stackTrace);
    }, onDone: () {
      _onSocketClose();
    }, cancelOnError: cancelOnErrorFlag);
  }

  void send(String message) {
    _log.finest('Sending $message');
    _webSocketCh.sink.add(message);
  }

  void _onData(dynamic data) {
    _log.finest('Received raw from Server: $data');
    if (msgDecoder == null) {
      // selection of message decoder is delayed until receiving first message from socket
      _selectMessageDecoder();
    }
    var decoded = msgDecoder!.decode(data);
    _log.finest('Received Decoded: $decoded');
    // decodes message received and pushes it to the stream
    _localStream.add(decoded);
  }

  void _onSocketError(WebSocketChannelException error, StackTrace stackTrace) {
    _log.severe('onSocketError: $error');
    _log.severe('onSocketError: $stackTrace');

    if (_heartbeatTimer != null) {
      _heartbeatTimer!.cancel();
    }

    _signalSocketError(error);
  }

  void _onSocketClose() {
    _log.warning(
        'onSocketClose, code: ${_webSocketCh.closeCode}, reason: ${_webSocketCh.closeReason}');
    if (_heartbeatTimer != null) {
      _heartbeatTimer?.cancel();
    }

    _signalSocketClose(_webSocketCh.closeCode, _webSocketCh.closeReason);
  }

  void resetHeartbeat() {
    pendingHeartbeatRef = null;
    if (_heartbeatTimer != null) {
      _heartbeatTimer?.cancel();
    }
    _heartbeatTimer =
        Timer.periodic(Duration(milliseconds: _heartbeatIntervalMs), (Timer t) {
      sendHeartbeat();
    });
  }

  void sendHeartbeat() {
    if (!isOpen()) {
      return;
    }
    if (pendingHeartbeatRef != null) {
      pendingHeartbeatRef = null;
      const reason = 'heartbeat timeout. Attempting to re-establish connection';
      _log.warning('transport: $reason');
      _abnormalClose(reason);

      return;
    }
    pendingHeartbeatRef = _makeRef();
    send('hb::$pendingHeartbeatRef');
  }

  void _abnormalClose(reason) {
    _log.fine('Abnormal Close');
    close(StatusCodes.error, reason);
  }

  String _makeRef() {
    var newRef = _ref + 1;
    if (newRef == _ref) {
      _ref = 0;
    } else {
      _ref = newRef;
    }

    return _ref.toString();
  }

  void _selectMessageDecoder() {
    if (getProtocol() == 'binary_flow') {
      msgDecoder = BinaryDecoder();
    } else {
      msgDecoder = JsonDecoder();
    }
    _log.finest('Decoder selected : $msgDecoder');
  }
}
