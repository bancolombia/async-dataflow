import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:web_socket_channel/io.dart';

import 'async_config.dart';
import 'retry_timer.dart';
import 'channel_message.dart';
import 'transport.dart';

/// Async Data Flow Low Level Client
///
/// This library allows you to connect do Async Dataflow Channel 
/// Sender.
///
class AsyncClient {
  
  final _log = Logger('AsyncClient');
  
  static const String JSON_FLOW = 'json_flow';
  static const String BINARY_FLOW = 'binary_flow';
  static const String RESPONSE_AUTH_OK = 'AuthOk';
  static const String RESPONSE_HB = ':hb';
  static const String RESPONSE_NEW_TOKEN = ':n_token';
  static const String EVENT_KIND_SYSTEM = 'system_event';
  static const String EVENT_KIND_USER = 'user_event';

  static final Random _random = Random.secure();

  final AsyncConfig _config;

  List<String> _subProtocols;
  Transport _transport;
  String _actualToken;
  RetryTimer _connectRetryTimer;
  IOWebSocketChannel _channel;
  // ----
  StreamSubscription<dynamic> _socketStreamSub;
  StreamController<ChannelMessage> _localStream;
  Stream<ChannelMessage> _broadCastStream;
  // ----

  AsyncClient(this._config) {
    _actualToken = _config.channel_secret;

    _subProtocols = [JSON_FLOW];
    if (_config.enable_binary_transport) {
      _subProtocols.add(BINARY_FLOW);
    }

    _localStream = StreamController(
      onListen: _onListen
    );

    _connectRetryTimer = RetryTimer(() async {
      _openChannel();
      _buildTransport();
      _onListen();
      return 1;
    });
  }

  /// Opens up the connection and performs auth flow.
  ///
  AsyncClient connect() {
    if (_transport != null && _transport.isOpen()) {
      _log.warning('Connect: Transport is aready open');
      return this;
    }

    // connect to channel
    _openChannel();

    // prepare local stream pipeline
    _broadCastStream = _localStream.stream
      .map((message) {
        var kind = EVENT_KIND_SYSTEM;
        if (message.event == RESPONSE_AUTH_OK){
            _handleAuthResponse(message);
        } else if(message.event == RESPONSE_HB && message.correlation_id == _transport.pendingHeartbeatRef){
            _handleCleanHeartBeat(message);
        } else if(message.event == RESPONSE_NEW_TOKEN){
            _handleNewToken(message);
        } else {
          kind = EVENT_KIND_USER;
        }
        return [message, kind];
      })
      .where((data) => data[1] == EVENT_KIND_USER) // only allows passing user events from this point
      .map((data) {
        // performs an ack of the user message received
        _ackMessage(data[0]);
        return data[0];
      });

    // build transport object
    _buildTransport();

    _log.finest('ADF connection');
    _broadCastStream = _broadCastStream.asBroadcastStream();
    return this;
  }

  StreamSubscription<ChannelMessage> subscribeTo(String eventFilter, Function onData, {Function onError}) {
    if (onError != null) {
      return subscribeToMany([eventFilter], onData, onError: onError);
    } else {
      return subscribeToMany([eventFilter], onData);
    }
  }

  StreamSubscription<ChannelMessage> subscribeToMany(List<String> eventFilters, Function onData, {Function onError}) {
    if (eventFilters == null || eventFilters.isEmpty) {
      throw ArgumentError('Invalid event filter(s)');
    } else {
      eventFilters.forEach((element) {
        if (element == null || element.trim().isEmpty) {
          throw ArgumentError('Invalid event filter');
        }
      });
    }
    if (onData == null) {
      throw ArgumentError('Invalid onData function');
    }
    return _broadCastStream.listen((message) {
      if (eventFilters.contains(message.event)) {
        onData(message);
      }
    }, onError: (error, stacktrace) {
      if (onError != null) {
        onError(error);
      }
    }, onDone: () {
      _log.warning('Subscription for "$eventFilters" terminated.');
    });
  }

  void _openChannel() {
    try {
      _channel = IOWebSocketChannel.connect(_config.socket_url + '?channel=' + _config.channel_ref, 
        protocols: _subProtocols,
        headers: _buildHeaders(), 
      );
      _log.finest('New websocket connection');
    } catch (e) {
      _channel = null;
      _log.severe('Error creating websocket connection: $e');
    }
  }

  void _buildTransport() {
    try {
      _transport = Transport(_channel, _localStream, _onTransportClose, _onTransportError, _config.heartbeat_interval);
      _log.finest('Transport configured');
    } catch (e) {
      _channel = null;
      _log.severe('Error configuring transport: $e');
    }
  }

  bool isOpen() {
    return _transport.isOpen();
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

  /// Disconnects client with ADF channel sender
  ///
  Future<bool> disconnect() async {
    await _transport.close(1000, 'Client disconnect');
    _connectRetryTimer.reset();
    _log.finer('transport closed');
    return true;
  }

  // void listenEvent(String eventName, {Function callback})  {
  //   _bindings[eventName] = callback;
  //   _log.fine('added callback for "$eventName"');
  // }

  void _handleAuthResponse(ChannelMessage message) {
    _transport.resetHeartbeat();
    _connectRetryTimer.reset();
  }

  void _handleCleanHeartBeat(ChannelMessage message) {
    _transport.pendingHeartbeatRef = null;
  }

  /// Function to handle the refreshed channel secret sent by the server
  ///
  void _handleNewToken(ChannelMessage message) {
    _actualToken = message.payload;
    _ackMessage(message);
  }

  // void _handleUserMessage(ChannelMessage message) {
  //   _ackMessage(message);
  //   var callback = bindings[message.event];
  //   if (callback != null) {
  //     callback(message);
  //   } else {
  //     log.finer('Binding for event "${message.event}" not defined');
  //   }
  // }

  void _ackMessage(ChannelMessage message) {
    if (message != null && message.message_id != null && message.message_id.isNotEmpty) {
      _transport.send('Ack::${message.message_id}');
    }
  }

  void _onTransportClose(int code, String reason) {
    _socketStreamSub.cancel();
    _socketStreamSub = null;
    _transport = null;

    switch(code) {
      case 1008: {
        _log.severe('Transport closed due invalid credentials, not reconnecting!');
      }
      break;
      default: {
        _log.severe('Transport not closed cleanly, Scheduling reconnect...');
        _connectRetryTimer.schedule();
      }
    }
  }

  void _onTransportError(Object error) {
    if (!_transport.isOpen()) {
      _log.severe('Transport error and channel is not open, Scheduling reconnect...');

      _socketStreamSub.cancel();
      _socketStreamSub = null;
      _transport = null;
    
      _connectRetryTimer.schedule();
    }

    // switch(code) {
    //   case 1008: {
    //     _log.severe('Transport closed due invalid credentials, not reconnecting!');
    //   }
    //   break;
    //   default: {
    //     _log.severe('Transport not closed cleanly, Scheduling reconnect...');
    //     _connectRetryTimer.schedule();
    //   }
    // }
  }

  void _onListen() {
    print('onListen called');
    _socketStreamSub = _transport.subscribe(cancelOnErrorFlag: true);
    _transport.send('Auth::$_actualToken');
  }


}