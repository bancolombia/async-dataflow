import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../channel_sender_client.dart';
import '../decoder/binary_decoder.dart';
import '../decoder/json_decoder.dart';
import '../decoder/message_decoder.dart';
import '../utils/retry_timer.dart';
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
  static final Random _random = Random.secure();

  String? pendingHeartbeatRef;

  final _log = Logger('WSTransport');
  late IOWebSocketChannel _webSocketCh;
  final AsyncConfig _config;
  final Function(int, String) _signalSocketClose;
  final Function(Object) _signalSocketError;

  late List<String> _subProtocols;
  late Stream<ChannelMessage> _broadCastStream; // subscribers stream of data
  late String currentToken;

  // ----
  StreamSubscription<dynamic>? _socketStreamSub;
  late StreamController<ChannelMessage> _localStream;

  late RetryTimer _connectRetryTimer;

  // ----

  int _ref = 0;
  bool _closeWasClean = false;
  Timer? _heartbeatTimer;

  set webSocketCh(IOWebSocketChannel value) {
    _webSocketCh = value;
  }

  set localStream(StreamController<ChannelMessage> value) {
    _localStream = value;
  }

  WSTransport(
    this._signalSocketClose,
    this._signalSocketError,
    this._config,
  ) {
    currentToken = _config.channelSecret;
    _subProtocols = configSubProtocol();
    _localStream = StreamController(onListen: _onListen);

    _connectRetryTimer = RetryTimer(
      () async {
        connect();
        _onListen();

        return 1;
      },
      maxRetries: _config.maxRetries,
    );
  }

  @override
  TransportType name() {
    return TransportType.ws;
  }

  @override
  void connect() {
    _webSocketCh = _openChannel();
    if (isOpen()) {
      _log.info('async-client. socket already created');

      return;
    }
    msgDecoder ??= _selectMessageDecoder();

    _log.info('async-client. New websocket connection ${_config.channelRef}');
    _broadCastStream = _localStream.stream
        .map((message) {
          _log.finest('async-clientttt. Received message: $message');
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

          return [message, kind];
        })
        .where((data) =>
            data.last ==
            EVENT_KIND_USER) // only allows passing user events from this point
        .map((data) {
          // performs an ack of the user message received
          final message = data.first as ChannelMessage;
          _ackMessage(message);

          return message;
        });

    _log.info('async-client. ADF connection');
    _broadCastStream = _broadCastStream.asBroadcastStream();
  }

  @override
  Future<void> disconnect() async {
    await close(1000, 'Client disconnect');
    await _socketStreamSub?.cancel();
    _socketStreamSub = null;
  }

  @override
  bool isOpen() {
    return _webSocketCh.innerWebSocket != null && readyState() == 1;
  }

  @override
  Stream<ChannelMessage> get stream => _broadCastStream;

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
        _onSocketClose(
            _webSocketCh.closeCode ?? 1000, _webSocketCh.closeReason ?? '');
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

  void _onSocketClose(int code, String reason) {
    _log.warning(
      'async-client. onSocketClose, code: $code, reason: $reason',
    );
    if (_heartbeatTimer != null) {
      _heartbeatTimer?.cancel();
    }
    int reasonCode = extractCode(reason);
    bool shouldRetry = code > 1001 || (code == 1001 && reasonCode >= 3050);

    if (!_closeWasClean &&
        shouldRetry &&
        reason != 'Invalid token for channel') {
      _log.info('async-client. Scheduling reconnect, clean: $_closeWasClean');
      _connectRetryTimer.schedule();
    } else {
      disconnect();
    }
    _signalSocketClose(
      code,
      reason,
    );
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
      _log.warning('async-client. transport: $reason');
      _abnormalClose(reason);

      return;
    }
    pendingHeartbeatRef = _makeRef();
    send('hb::$pendingHeartbeatRef');
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
    MessageDecoder decoder = getProtocol() == 'binary_flow'
        ? BinaryDecoder()
        : JsonDecoder() as MessageDecoder;
    _log.finest('async-client. Decoder selected : $decoder');

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

  IOWebSocketChannel _openChannel() {
    var url = '${_config.socketUrl}?channel=${_config.channelRef}';

    return IOWebSocketChannel.connect(
      url,
      protocols: _subProtocols,
      headers: _buildHeaders(),
    );
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
    _socketStreamSub = subscribe(cancelOnErrorFlag: true);
    send('Auth::$currentToken');
  }

  void dispose() {
    _log.finest('async-client.local stream dispose');

    _localStream.close();
  }

  int extractCode(String stringCode) {
    return int.tryParse(stringCode) ?? 0;
  }
}
