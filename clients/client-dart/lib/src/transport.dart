import 'dart:async';
import 'package:logging/logging.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class Transport {

  final log = Logger('Transport');
  
  final IOWebSocketChannel _webSocketCh;
  String pendingHeartbeatRef;
  int _ref = 0;
  bool closeWasClean = false;
  Timer heartbeatTimer;
  int heartbeatIntervalMs = 1000;

  Transport(this._webSocketCh, this.heartbeatIntervalMs);
  
  bool isOpen() {
    return _webSocketCh.innerWebSocket != null
      && readyState() == 1;
  }

  int readyState() {
    var readyState = 0;
    if (_webSocketCh.innerWebSocket != null) {
      readyState = _webSocketCh.innerWebSocket.readyState;
    }
    return readyState;
  }

  String getProtocol() {
    return _webSocketCh.protocol;
  }

  Future<dynamic> close(int code, String reason) async {
    closeWasClean = true;
    if (heartbeatTimer != null) {
      heartbeatTimer.cancel();
    }
    return await _webSocketCh.sink.close(code, reason);
  }

  int getCloseCode() {
    return _webSocketCh.closeCode;
  }

  Future<int> attach(Function dataFn, Function closeFn, bool cancelOnErrorFlag) {
    _webSocketCh.stream.listen(
      (data) {
          dataFn(data);
      },
      onError: (error, stackTrace) {
        _onSocketError(error, stackTrace);
      }, 
      onDone: () {
        _onSocketClose(closeFn);
      }, 
      cancelOnError: cancelOnErrorFlag);
      return Future.value(0);
  }

  void send(String message) {
    log.finest('Sending $message');
    _webSocketCh.sink.add(message);
  }

  void _onSocketError(WebSocketChannelException error, StackTrace stackTrace) {
    log.severe('onSocketError: $error');
    if (heartbeatTimer != null) {
      heartbeatTimer.cancel();
    }
  }

  void _onSocketClose(Function callback) {
    log.warning('onSocketClose, code: ${_webSocketCh.closeCode}, reason: ${_webSocketCh.closeReason}');
    if (heartbeatTimer != null) {
      heartbeatTimer.cancel();
    }
    callback(_webSocketCh.closeCode, _webSocketCh.closeReason);
  }

  void resetHeartbeat() {
    pendingHeartbeatRef = null;
    if (heartbeatTimer != null) {
      heartbeatTimer.cancel();
    }
    heartbeatTimer = Timer.periodic(Duration(milliseconds: heartbeatIntervalMs), (Timer t) {
      _sendHeartbeat();
    });
  }

  void _sendHeartbeat() {
    if (!isOpen()){ return; } 
    if (pendingHeartbeatRef != null) {
        pendingHeartbeatRef = null;
        const reason = 'heartbeat timeout. Attempting to re-establish connection';
        log.warning('transport: $reason');
        _abnormalClose(reason);
        return;
    }
    pendingHeartbeatRef = _makeRef();
    send('hb::$pendingHeartbeatRef');
  }

  void _abnormalClose(reason){
    closeWasClean = false;
    log.fine('Abnormal Close: Modify clean to: $closeWasClean');
    _webSocketCh.sink.close(1000, reason);
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

  List<String> _tokenize(String dataReceived) {
    return dataReceived.split(',')
      .map((e) => e.trim())
      .map((e) => e.replaceAll(RegExp(r'["]{2}'), ''))
      .map((e) => e.replaceAll(RegExp(r'^"'), ''))
      .map((e) => e.replaceAll(RegExp(r'"$'), ''))
      .toList();
  }
}