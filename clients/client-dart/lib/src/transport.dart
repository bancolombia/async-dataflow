import 'dart:async';
import 'package:logging/logging.dart';
import 'package:web_socket_channel/io.dart';
class Transport {

  final log = Logger('Transport');
  
  final IOWebSocketChannel _webSocketCh;
  bool isActive = false;
  String pendingHeartbeatRef;
  int _ref = 0;
  bool closeWasClean = false;
  Timer heartbeatTimer;
  int heartbeatIntervalMs = 1000;

  Transport(this._webSocketCh, this.heartbeatIntervalMs);
  
  bool isOpen() {
    return _webSocketCh != null;
  }

  int readyState() {
    var readyState = -999;
    if (_webSocketCh.innerWebSocket != null) {
      readyState = _webSocketCh.innerWebSocket.readyState;
    }
    log.severe('ready state: $readyState');
    return readyState;
  }

  String getProtocol() {
    return _webSocketCh.protocol;
  }

  Future<dynamic> close(int code, String reason) async {
    closeWasClean = true;
    isActive = false;
    heartbeatTimer.cancel();
    return await _webSocketCh.sink.close(code, reason);
  }

  int getCloseCode() {
    return _webSocketCh.closeCode;
  }

  void attach(Function dataFn, Function closeFn, bool cancelOnErrorFlag) {
    _webSocketCh.stream.listen(
      (data) {
          dataFn(data);
      },
      onError: (error) {
        log.severe('Received Error: $error');
      }, 
      onDone: () {
        _onSocketClose(closeFn);
      }, 
      cancelOnError: cancelOnErrorFlag);
  }

  void send(String message) {
    if (isOpen()) {
      log.finest('Sending $message');
      _webSocketCh.sink.add(message);
    }
  }

  void _onSocketClose(Function callback) {
    log.fine('Async channel close, code: ${_webSocketCh.closeCode}');
    heartbeatTimer.cancel();
    callback(_webSocketCh.closeCode);
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
    if (!isActive){ return; } 
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
    log.fine('_abClose Modify clean to: $closeWasClean');
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