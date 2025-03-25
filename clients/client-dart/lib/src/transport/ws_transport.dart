import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:web_socket_channel/io.dart';

import '../../channel_sender_client.dart';
import '../decoder/binary_decoder.dart';
import '../decoder/json_decoder.dart';
import '../decoder/message_decoder.dart';
import '../utils/retry_timer.dart';
import 'max_retries_exception.dart';
import 'transport.dart';

class WSTransport implements Transport {
  MessageDecoder msgDecoder = JsonDecoder();
  static const String JSON_FLOW = 'json_flow';
  static const String BINARY_FLOW = 'binary_flow';
  static const String RESPONSE_AUTH_OK = 'AuthOk';
  static const String RESPONSE_HB = ':hb';
  static const String RESPONSE_NEW_TOKEN = ':n_token';
  static const String EVENT_KIND_SYSTEM = 'system_event';
  static const String EVENT_KIND_USER = 'user_event';

  static const int SOCKET_NORMAL_CLOSE = 1000;
  static const int SOCKET_GOING_AWAY = 1001;
  static const int SENDER_INVALID_REF = 3050;

  static const int RETRY_DEFAULT_MAX_RETRIES = 5;

  static final Random _random = Random.secure();

  String? pendingHeartbeatRef;
  late String currentToken;

  final _log = Logger('WSTransport');
  late IOWebSocketChannel _webSocketCh;
  final AsyncConfig _config;
  final Function(int, String) _signalSocketClose;
  final Function(Object) _signalSocketError;

  late List<String> _subProtocols;
  late StreamController<ChannelMessage> _broadCastStream;
  StreamSubscription? _socketStreamSub;
  late RetryTimer _connectRetryTimer;

  int _ref = 0;
  bool _closeWasClean = false;
  Timer? _heartbeatTimer;
  int _reconnectionAttempts = 0;

  set webSocketCh(IOWebSocketChannel value) {
    _webSocketCh = value;
  }

  WSTransport(
    this._signalSocketClose,
    this._signalSocketError,
    this._config,
  ) {
    _log.finer('[async-client][WSTransport] constructor start.');

    currentToken = _config.channelSecret;
    _subProtocols = configSubProtocol();
    // _localStream = StreamController(onListen: _onListen);
    _broadCastStream = StreamController<ChannelMessage>.broadcast(); // subscribers stream of data
    
    _connectRetryTimer = RetryTimer(
      () async {
        connect().then((res) { print(res);});

        return 1;
      },
      () async {
        _onSocketError(MaxRetriesException('[async-client][WSTransport] Max retries reached'), StackTrace.current);
      },
      maxRetries: _config.maxRetries,
    );
  }

  @override
  TransportType name() {
    return TransportType.ws;
  }

  @override
  Future<bool> connect() async {
    _log.finer('[async-client][WSTransport] connect() started.');
    
    if (isOpen()) {
      _log.info('[async-client][WSTransport] socket already created');
      
      return false;
    }

    // _webSocketCh = _openChannel();
    await _openChannel();

    msgDecoder = _selectMessageDecoder();

    _log.info('[async-client][WSTransport] New websocket connection ${_config.channelRef}');

    _onListen();

    _log.finer('[async-client][WSTransport] connect() finished.');

    return true;
  }

  @override
  Future<void> disconnect() async {
    _log.info('[async-client][WSTransport] disconnect() called.');
    _connectRetryTimer.reset();
    await close(SOCKET_NORMAL_CLOSE, 'Client disconnect');
    await _socketStreamSub?.cancel();
    _socketStreamSub = null;
  }

  @override
  bool isOpen() {
    bool isOpen = false;
    try {
      isOpen = _webSocketCh.innerWebSocket != null && readyState() == 1;
    }
    catch (e) {
      isOpen = false;
    }

    return isOpen;  
  }

  @override
  Stream<ChannelMessage> get stream => _broadCastStream.stream;

  int readyState() {
    var readyState = 0;

    if (_webSocketCh.innerWebSocket != null) {
      readyState = _webSocketCh.innerWebSocket?.readyState ?? 0;
    }

    return readyState;
  }

  String? getProtocol() {
    return _webSocketCh.protocol;
  }

  Future close(int code, String reason) async {
    _log.finest('[async-client][WSTransport] close() called.');
    _closeWasClean = true;
    if (_heartbeatTimer != null) {
      _heartbeatTimer?.cancel();
    }
    if (!isOpen()) {
      _log.finest('[async-client][WSTransport] close() innecesary, already closed.');
      return;
    }
    return await _webSocketCh.sink.close(code, reason);
  }

  int? getCloseCode() {
    return _webSocketCh.closeCode;
  }

  StreamSubscription subscribe({required bool cancelOnErrorFlag}) {
    _log.finest('[async-client][WSTransport] Creating stream from socket, with cancelOnErrorFlag=$cancelOnErrorFlag');

    try {
      _socketStreamSub = _webSocketCh.stream.listen(
        (data) {
          if (!_broadCastStream.isClosed) {
            _onData(data);
          }
        },
        onError: (error, stackTrace) {
          _log.severe('[async-client][WSTransport] signaling on error...');
          _onSocketError(error, stackTrace);
        },
        onDone: () {
          _log.finest('[async-client][WSTransport] Stream from socket DONE.');
          _onSocketClose(
              _webSocketCh.closeCode ?? SOCKET_NORMAL_CLOSE, _webSocketCh.closeReason ?? '');
        },
        cancelOnError: cancelOnErrorFlag,
      );
    } catch (e) {
      _log.severe('[async-client][WSTransport] Error subscribing to socket: $e');
    }

    return  _socketStreamSub!;
  }

  void send(String message) {
    _log.finest('[async-client][WSTransport] Sending > $message');
    _webSocketCh.sink.add(message);
  }

  void _onData(dynamic data) {
    _log.finest('[async-client][WSTransport] Received raw from Server: $data');  
    if (!_checkValidInputFrame(data)) {
      _log.warning('[async-client][WSTransport] Invalid frame received: $data');

      return;
    }
    var message = msgDecoder.decode(data);
    _log.finest('[async-client][WSTransport] Received Decoded: $message');

    var kind = EVENT_KIND_SYSTEM;
    if (message.event == RESPONSE_AUTH_OK) {
      _handleAuthResponse();
    } else if (message.event == RESPONSE_HB &&
        message.correlationId == pendingHeartbeatRef) {
      _handleCleanHeartBeat();
    } else if (message.event == RESPONSE_NEW_TOKEN) {
      _handleNewToken(message);
    } else {
      kind = EVENT_KIND_USER;
    }

    if (kind == EVENT_KIND_USER) {
      _ackMessage(message);
      // then stream
      _broadCastStream.add(message);
    } else if (kind == EVENT_KIND_SYSTEM && message.event == RESPONSE_NEW_TOKEN) {
      // just stream it, so app can handle it
      _broadCastStream.add(message);
    }

  }

  bool _checkValidInputFrame(dynamic data) {
    String dataStr = data.toString();
    const pattern = r'^\[".*?",\s?".*?",\s?".*?",\s?.*\]$';

    return RegExp(pattern).hasMatch(dataStr);
  }

  void _onSocketError(Exception error, StackTrace stackTrace) {
    _log.severe('[async-client][WSTransport] onSocketError: $error');

    var heartbeatTimer = _heartbeatTimer;
    if (heartbeatTimer != null) {
      heartbeatTimer.cancel();
    }

    if (_reconnectionAttempts > (_config.maxRetries ?? RETRY_DEFAULT_MAX_RETRIES)) {
      _log.warning('[async-client][WSTransport] Max retries reached');
      _signalSocketError(error);
    } else {
      _log.warning('[async-client][WSTransport] Scheduling reconnect');
      _reconnectionAttempts++;
      _connectRetryTimer.schedule();
    }

  }

  void _onSocketClose(int code, String reason) {
    _log.warning(
      '[async-client][WSTransport] onSocketClose, code: $code, reason: $reason',
    );
    if (_heartbeatTimer != null) {
      _heartbeatTimer?.cancel();
    }
    int reasonCode = extractCode(reason);
    bool shouldRetry = code > SOCKET_GOING_AWAY || (code == SOCKET_GOING_AWAY && reasonCode >= SENDER_INVALID_REF);
    _log.info('[async-client][WSTransport] shouldRetry: $shouldRetry');

    if (!_closeWasClean &&
        shouldRetry &&
        reason != 'Invalid token for channel') {
      _log.info('[async-client][WSTransport] Scheduling reconnect, clean: $_closeWasClean');
      _connectRetryTimer.schedule();
    } else {
      _log.info('[async-client][WSTransport] Not scheduling reconnect, clean: $_closeWasClean');
      disconnect();

      _signalSocketClose(code, reason,);
    }
  }

  void resetHeartbeat() {
    pendingHeartbeatRef = null;
    if (_heartbeatTimer != null) {
      _heartbeatTimer?.cancel();
    }
    _heartbeatTimer =
        Timer.periodic(Duration(milliseconds: _config.hbInterval), (Timer t) {
      sendHeartbeat();
    });
  }

  void sendHeartbeat() {
    if (!isOpen()) {
      return;
    }
    if (pendingHeartbeatRef != null) {
      pendingHeartbeatRef = null;
      String reason =
          'heartbeat timeout. Attempting to re-establish connection heartbeat interval ${_config.hbInterval} ms';
      _log.warning('[async-client][WSTransport] transport: $reason');
      _abnormalClose(reason);

      return;
    }
    pendingHeartbeatRef = _makeRef();
    send('hb::$pendingHeartbeatRef');
  }

  void _abnormalClose(reason) {
    _log.warning('[async-client][WSTransport] Abnormal Close');
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
    MessageDecoder decoder = getProtocol() == 'binary_flow'
        ? BinaryDecoder()
        : JsonDecoder() as MessageDecoder;
    _log.finest('[async-client][WSTransport] Decoder selected : $decoder');

    return decoder;
  }

  void _handleAuthResponse() {
    resetHeartbeat();
    _connectRetryTimer.reset();
  }

  void _handleCleanHeartBeat() {
    pendingHeartbeatRef = null;
  }

  // Function to handle the refreshed channel secret sent by the server
  void _handleNewToken(ChannelMessage message) {
    currentToken = message.payload;
    // updates the token in the config
    _config.channelSecret = currentToken;
    _ackMessage(message);
  }

  void _ackMessage(ChannelMessage? message) {
    if (message != null) {
      var messageId = message.messageId;
      if (messageId != null && messageId.isNotEmpty) {
        send('Ack::${message.messageId}');
      }
    }
  }

  // IOWebSocketChannel _openChannel() {
  //   var url = '${_config.socketUrl}?channel=${_config.channelRef}';

  //   return IOWebSocketChannel.connect(
  //     url,
  //     protocols: _subProtocols,
  //     headers: _buildHeaders(),
  //   );
  // }

  Future<void> _openChannel() async {
    try {
      _webSocketCh = await _sockOpen();

      // Wait until the WebSocket is open
      int retries = _config.maxRetries ?? RETRY_DEFAULT_MAX_RETRIES;
      await Future.doWhile(() async {
        await Future.delayed(Duration(milliseconds: 250)); // Small delay
        
        _log.finest('[async-client][WSTransport] Waiting for WebSocket to open... retries: $retries');
        retries--;
        if (retries <= 0) {
          _log.warning('[async-client][WSTransport] WebSocket did not open');

          return false;
        } else {

          return _webSocketCh.innerWebSocket?.readyState != 1;
        }
      });   
    } catch (e) {
      _log.warning('[async-client][WSTransport] Unknown Error opening WebSocket: $e');
    }

  }

  Future<IOWebSocketChannel> _sockOpen() async {
    var url = '${_config.socketUrl}?channel=${_config.channelRef}';

    try {
      return IOWebSocketChannel.connect(
        url,
        protocols: _subProtocols,
        headers: _buildHeaders(),
      );
    } catch (e) {
      // this will only catch synchronous errors
      _log.warning('[async-client][WSTransport] Unknown Error opening WebSocket: $e');
      throw Exception('Network error');
    }
  }

  List<String> configSubProtocol() {
    List<String> sbProtocols = [JSON_FLOW];
    if (_config.enableBinaryTransport) {
      sbProtocols.add(BINARY_FLOW);
    }

    return sbProtocols;
  }

  Map<String, dynamic> _buildHeaders() {
    var headers = <String, dynamic>{};
    headers['Connection'] = 'upgrade';
    headers['Upgrade'] = 'websocket';
    headers['sec-websocket-version'] = '13';
    headers['sec-websocket-protocol'] = _subProtocols;
    headers['sec-websocket-key'] = _generateSocketKey();

    return headers;
  }

  String _generateSocketKey() {
    var values = List<int>.generate(8, (i) => _random.nextInt(255));

    return base64Url.encode(values);
  }

  void _onListen() {
    _log.finest('[async-client][WSTransport] _onListen() called');
    _socketStreamSub = null;
    _socketStreamSub = subscribe(cancelOnErrorFlag: true);
    send('Auth::$currentToken');
    _log.finest('[async-client][WSTransport] _onListen() call ends');
  }

  void dispose() {
    _log.finest('[async-client][WSTransport] local stream dispose');
    _broadCastStream.close();
    // _localStream.close();
  }

  int extractCode(String stringCode) {
    return int.tryParse(stringCode) ?? 0;
  }
}
