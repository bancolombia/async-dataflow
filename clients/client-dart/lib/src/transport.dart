import 'dart:async';

import 'package:logging/logging.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'binary_decoder.dart';
import 'channel_message.dart';
import 'json_decoder.dart';
import 'message_decoder.dart';

class Transport {
  MessageDecoder msgDecoder = JsonDecoder();
  String? pendingHeartbeatRef;

  final _log = Logger('Transport');
  final IOWebSocketChannel _webSocketCh;
  final StreamController<ChannelMessage> _localStream;
  final int _heartbeatIntervalMs;
  final Function(int, String) _signalSocketClose;
  final Function(Object) _signalSocketError;

  int _ref = 0;
  bool _closeWasClean = false;
  Timer? _heartbeatTimer;

  Transport(
    this._webSocketCh,
    this._localStream,
    this._signalSocketClose,
    this._signalSocketError,
    this._heartbeatIntervalMs,
  ) {
    msgDecoder = _selectMessageDecoder();
  }

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

  bool isClosedCleanly() => _closeWasClean;

  Future close(int code, String reason) async {
    _closeWasClean = true;
    if (_heartbeatTimer != null) {
      _heartbeatTimer?.cancel();
    }

    return await _webSocketCh.sink.close(code, reason);
  }

  int? getCloseCode() {
    return _webSocketCh.closeCode;
  }

  StreamSubscription subscribe({required bool cancelOnErrorFlag}) {
    return _webSocketCh.stream.listen(
      (data) {
        _onData(data);
      },
      onError: (error, stackTrace) {
        _onSocketError(error, stackTrace);
      },
      onDone: () {
        _onSocketClose();
      },
      cancelOnError: cancelOnErrorFlag,
    );
  }

  void send(String message) {
    _log.finest('async-client. Sending $message');
    _webSocketCh.sink.add(message);
  }

  void _onData(dynamic data) {
    _log.finest('async-client. Received raw from Server: $data');
    var decoded = msgDecoder.decode(data);
    _log.finest('async-client. Received Decoded: $decoded');
    // decodes message received and pushes it to the stream
    _localStream.add(decoded);
  }

  void _onSocketError(WebSocketChannelException error, StackTrace stackTrace) {
    _log.severe('async-client. onSocketError: $error $stackTrace');

    var heartbeatTimer = _heartbeatTimer;
    if (heartbeatTimer != null) {
      heartbeatTimer.cancel();
    }

    _signalSocketError(error);
  }

  void _onSocketClose() {
    _log.warning(
      'async-client. onSocketClose, code: ${_webSocketCh.closeCode}, reason: ${_webSocketCh.closeReason}',
    );
    if (_heartbeatTimer != null) {
      _heartbeatTimer?.cancel();
    }

    _signalSocketClose(
      _webSocketCh.closeCode ?? 1000,
      _webSocketCh.closeReason ?? '',
    );
  }

  void resetHeartbeat() {
    pendingHeartbeatRef = null;
    if (_heartbeatTimer != null) {
      _heartbeatTimer?.cancel();
    }
    _heartbeatTimer = Timer.periodic(
      Duration(milliseconds: _heartbeatIntervalMs),
      (Timer t) {
        sendHeartbeat();
      },
    );
  }

  void sendHeartbeat() {
    if (!isOpen()) {
      return;
    }
    if (pendingHeartbeatRef != null) {
      pendingHeartbeatRef = null;
      String reason =
          'heartbeat timeout. Attempting to re-establish connection heartbeat interval $_heartbeatIntervalMs';
      _log.warning('async-client. transport: $reason');
      _abnormalClose(reason);

      return;
    }
    pendingHeartbeatRef = _makeRef();
    send('hb::$pendingHeartbeatRef');
  }

  void refreshToken(currentToken) {
    if (!isOpen()) {
      return;
    }
    send('n_token::$currentToken');
  }

  void _abnormalClose(reason) {
    _log.warning('async-client. Abnormal Close');
    _closeWasClean = false;
    const heartbeatCode = 3051;
    _webSocketCh.sink.close(heartbeatCode, reason);
  }

  String _makeRef() {
    var newRef = _ref + 1;
    _ref = newRef == _ref ? 0 : newRef;

    return _ref.toString();
  }

  MessageDecoder _selectMessageDecoder() {
    MessageDecoder decoder =
        getProtocol() == 'binary_flow'
            ? BinaryDecoder()
            : JsonDecoder() as MessageDecoder;
    _log.finest('async-client. Decoder selected : $decoder');

    return decoder;
  }
}
