import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'message_decoder.dart';
import 'async_config.dart';
import 'binary_decoder.dart';
import 'json_decoder.dart';
import 'retry_timer.dart';
import 'channel_message.dart';
import 'transport.dart';
import 'package:logging/logging.dart';
import 'package:web_socket_channel/io.dart';

/// Async Data Flow Low Level Client
///
/// This library allows you to connect do Async Dataflow Channel 
/// Sender.
///
class AsyncClient {
  
  final log = Logger('AsyncClient');

  static final Random _random = Random.secure();

  Transport transport;
  AsyncConfig config;
  String actualToken;
  RetryTimer reconnectTimer;
  Map<String, Function> bindings = {};
  List<String> subProtocols = [];
  MessageDecoder msgDecoder;

  AsyncClient(this.config) {
    actualToken = config.channel_secret;
    subProtocols.add('json_flow');
    if (config.enable_binary_transport) {
      subProtocols.add('binary_flow');
    }
    reconnectTimer = RetryTimer(() => connect());
    log.info('AsyncClient new instance');
  }

  /// Opens up the connection and performs auth flow.
  ///
  Future<bool> connect() async {
    if (transport != null && transport.isOpen()) {
      log.info('Connect Request: Transport is aready open');
      return Future.value(true);
    }
    
    try {
      // connect to channel
      var channel = IOWebSocketChannel.connect(config.socket_url + '?channel=' + config.channel_ref, 
        protocols: subProtocols,
        headers: _buildHeaders(), 
      );

      // build transport object
      transport = Transport(channel, config.heartbeat_interval);

      // attachs functions to socket stream
      await transport.attach(
        _doOnSocketMessage, _onTransportClose, false
      );

      // send credentials
      transport.send('Auth::$actualToken');

      return Future.delayed(Duration(milliseconds: 200), () => transport.isOpen());

    } catch (e) {
      log.severe('Error connecting: $e');
    }
  }

  bool isOpen() {
    return transport.isOpen();
  }

  Map<String, dynamic> _buildHeaders() {
    var headers = <String, dynamic>{}; 
    headers['Connection'] = 'upgrade';
    headers['Upgrade'] = 'websocket';
    headers['sec-websocket-version'] = '13';
    headers['sec-websocket-protocol'] = subProtocols;
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
    await transport.close(1000, 'Client disconnect');
    reconnectTimer.reset();
    log.finer('transport closed');
    return true;
  }

  void listenEvent(String eventName, {Function callback})  {
    bindings[eventName] = callback;
    log.fine('added callback for "$eventName"');
  }

  /// Method that handles messages received by the server 
  ///
  void _doOnSocketMessage(Object dataReceived) {
    
    if (msgDecoder == null) {
      // selection of message decoder is delayed until receiving first message from socket
      _selectMessageDecoder();
    }

    var message = msgDecoder.decode(dataReceived);

    log.finest('Received from Server: $message');

    if (message.event == 'AuthOk'){
        _handleAuthResponse(message);
    } else if(message.event == ':hb' && message.correlation_id == transport.pendingHeartbeatRef){
        _handleCleanHeartBeat(message);
    } else if(message.event == ':n_token'){
        _handleNewToken(message);
    } else {
        _handleUserMessage(message);
    }
  }

  void _selectMessageDecoder() {
    if (transport.getProtocol() == 'binary_flow') {
      msgDecoder = BinaryDecoder();
    } else {
      msgDecoder = JsonDecoder();
    }
  }

  void _handleAuthResponse(ChannelMessage message) {
    transport.resetHeartbeat();
    reconnectTimer.reset();
    log.info('channel is open? ${transport.isOpen()}');
  }

  void _handleCleanHeartBeat(ChannelMessage message) {
    transport.pendingHeartbeatRef = null;
  }

  /// Function to handle the refreshed channel secret sent by the server
  ///
  void _handleNewToken(ChannelMessage message) {
    actualToken = message.payload;
    log.fine(':n_token: $actualToken');
    _ackMessage(message);
  }

  void _handleUserMessage(ChannelMessage message) {
    _ackMessage(message);
    var callback = bindings[message.event];
    if (callback != null) {
      callback(message);
    } else {
      log.finer('Binding for event "${message.event}" not defined');
    }
  }

  void _ackMessage(ChannelMessage message) {
    transport.send('Ack::${message.message_id}');
  }

  void _onTransportClose(int code, String reason) {
    switch(code) {
      case 1008: {
        log.severe('Transport closed due invalid credentials, not reconnecting!');
      }
      break;
      default: {
        log.severe('Transport not closed cleanly, Scheduling reconnect...');
        reconnectTimer.schedule();
      }
    }
  }

}