import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:web_socket_channel/io.dart';

import 'async_config.dart';
import 'channel_message.dart';
import 'retry_timer.dart';
import 'transport.dart';

/// Async Data Flow Low Level Client
///
/// This library allows you to connect do Async Dataflow Channel
/// Sender.
///
class AsyncClient {
  static const String JSON_FLOW = 'json_flow';
  static const String BINARY_FLOW = 'binary_flow';
  static const String RESPONSE_AUTH_OK = 'AuthOk';
  static const String RESPONSE_HB = ':hb';
  static const String RESPONSE_NEW_TOKEN = ':n_token';
  static const String EVENT_KIND_SYSTEM = 'system_event';
  static const String EVENT_KIND_USER = 'user_event';

  final _log = Logger('AsyncClient');
  static final Random _random = Random.secure();
  final AsyncConfig _config;

  late List<String> _subProtocols;
  Transport? _transport;
  late String _currentToken;
  late RetryTimer _connectRetryTimer;
  late IOWebSocketChannel _channel;
  // ----
  StreamSubscription<dynamic>? _socketStreamSub;
  late StreamController<ChannelMessage> _localStream; // internal stream of data
  late Stream<ChannelMessage> _broadCastStream; // subscribers stream of data
  // ----

  AsyncClient(this._config) {
    _currentToken = _config.channelSecret;

    _subProtocols = [JSON_FLOW];
    if (_config.enableBinaryTransport) {
      _subProtocols.add(BINARY_FLOW);
    }

    // creates localstream
    _localStream = StreamController(onListen: _onListen);

    _connectRetryTimer = RetryTimer(
      () async {
        _openChannel();
        _buildTransport();
        _onListen();

        return 1;
      },
      maxRetries: _config.maxRetries,
    );
  }

  void dispose() {
    _localStream.close();
  }

  // Opens up the connection and performs auth flow.

  AsyncClient connect() {
    var transport = _transport;
    if (transport != null && transport.isOpen()) {
      _log.info('async-client. socket already created');

      return this;
    }

    // connect to channel
    _openChannel();

    // prepare local stream pipeline
    _broadCastStream = _localStream.stream
        .map((message) {
          var kind = EVENT_KIND_SYSTEM;
          if (message.event == RESPONSE_AUTH_OK) {
            _handleAuthResponse(message);
          } else if (message.event == RESPONSE_HB &&
              message.correlationId == _transport?.pendingHeartbeatRef) {
            _handleCleanHeartBeat(message);
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

    // build transport object
    _buildTransport();

    _log.info('async-client. ADF connection');
    _broadCastStream = _broadCastStream.asBroadcastStream();

    return this;
  }

  StreamSubscription<ChannelMessage> subscribeTo(
    String eventFilter,
    Function(ChannelMessage) onData, {
    Function? onError,
  }) {
    return onError != null
        ? subscribeToMany([eventFilter], onData, onError: onError)
        : subscribeToMany([eventFilter], onData);
  }

  StreamSubscription<ChannelMessage> subscribeToMany(
    List<String>? eventFilters,
    Function? onData, {
    Function? onError,
  }) {
    if (eventFilters == null || eventFilters.isEmpty) {
      throw ArgumentError('Invalid event filter(s)');
    } else {
      for (var element in eventFilters) {
        if (element.trim().isEmpty) {
          throw ArgumentError('Invalid event filter');
        }
      }
    }
    if (onData == null) {
      throw ArgumentError('Invalid onData function');
    }

    return _broadCastStream.listen(
      (message) {
        if (eventFilters.contains(message.event)) {
          onData(message);
        }
      },
      onError: (error, stacktrace) {
        if (onError != null) {
          onError(error);
        }
      },
      onDone: () {
        _log.warning(
          'async-client. Subscription for "$eventFilters" terminated.',
        );
      },
    );
  }

  void _openChannel() {
    try {
      var url = '${_config.socketUrl}?channel=${_config.channelRef}';
      _channel = IOWebSocketChannel.connect(
        url,
        protocols: _subProtocols,
        headers: _buildHeaders(),
      );
      _log.info('async-client. New websocket connection ${_config.channelRef}');
    } catch (e) {
      _log.severe('async-client. Error creating websocket connection: $e');
    }
  }

  void _buildTransport() {
    try {
      _transport = Transport(
        _channel,
        _localStream,
        _onTransportClose,
        _onTransportError,
        _config.hbInterval,
      );
      _log.info('async-client. Transport configured');
    } catch (e) {
      _log.severe('async-client. Error configuring transport: $e');
    }
  }

  bool isOpen() {
    return _transport?.isOpen() ?? false;
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

  Future<bool> disconnect() async {
    _log.finer('async-client. disconnect() called');

    await _transport?.close(1000, 'Client disconnect');
    _connectRetryTimer.reset();
    _log.finer('async-client. async-client. disconnect() called end');

    return true;
  }

  void _handleAuthResponse(ChannelMessage message) {
    _transport?.resetHeartbeat();
    _connectRetryTimer.reset();
  }

  void _handleCleanHeartBeat(ChannelMessage message) {
    _transport?.pendingHeartbeatRef = null;
  }

  // Function to handle the refreshed channel secret sent by the server
  void _handleNewToken(ChannelMessage message) {
    _currentToken = message.payload;
    _ackMessage(message);
  }

  void _ackMessage(ChannelMessage? message) {
    if (message != null) {
      var messageId = message.messageId;
      if (messageId != null && messageId.isNotEmpty) {
        _transport?.send('Ack::${message.messageId}');
      }
    }
  }

  void _onTransportClose(int code, String reason) {
    _log.fine('async-client. channel close: $code $reason');
    bool closeWasClean = _transport?.isClosedCleanly() ?? true;
    int reasonCode = extractCode(reason);
    bool shouldRetry = code > 1001 || (code == 1001 && reasonCode >= 3050);

    if (!closeWasClean &&
        shouldRetry &&
        reason != 'Invalid token for channel') {
      _log.info('async-client. Scheduling reconnect, clean: $closeWasClean');
      _connectRetryTimer.schedule();
    } else {
      cleanConnection();
    }
  }

  int extractCode(String stringCode) {
    return int.tryParse(stringCode) ?? 0;
  }

  void _onTransportError(Object error) {
    _log.severe('async-client. Transport error: $error');
    if (!isOpen()) {
      _log.severe(
        'async-client. Transport error and channel is not open, Scheduling reconnect...',
      );

      cleanConnection();

      _connectRetryTimer.schedule();
    }
  }

  void cleanConnection() {
    _socketStreamSub?.cancel();
    _socketStreamSub = null;
    _transport = null;
  }

  void _onListen() {
    _socketStreamSub = _transport?.subscribe(cancelOnErrorFlag: true);
    _transport?.send('Auth::$_currentToken');
  }
}
