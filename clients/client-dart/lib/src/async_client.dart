import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/io.dart';

import 'message_decoder.dart';
import 'async_config.dart';
import 'binary_decoder.dart';
import 'json_decoder.dart';
import 'retry_timer.dart';
import 'channel_message.dart';
import 'transport.dart';
import 'package:logging/logging.dart';

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
  MessageDecoder serializer;

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
  Future<int> connect() async {
    if (transport != null && transport.isOpen()) {
      log.info('Connect Request: Transport is aready open');
      return 0;
    }
    
    var channel = IOWebSocketChannel.connect(config.socket_url + '?channel=' + config.channel_ref, 
      protocols: subProtocols,
      headers: _buildHeaders()
    );
    
    transport = Transport(channel, config.heartbeat_interval ?? 750);
    transport.attach(_doOnSocketMessage, _onTransportClose, false);

    if (transport.isOpen()) {  
      _doAfterTransportOpen();
    }

    return Future(transport.readyState ?? -1);
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

  void _doAfterTransportOpen() {
    _selectSerializerForProtocol();
    transport.resetHeartbeat();
    log.fine('Presenting channel creds');
    transport.send('Auth::$actualToken');
  }

  void _selectSerializerForProtocol() {
    if (transport.getProtocol() == 'binary_flow') {
      serializer = BinaryDecoder();
    } else {
      serializer = JsonDecoder();
    }
  }

  /// Method that handles messages received by the server 
  ///
  void _doOnSocketMessage(String dataReceived) {
    log.finest('Received from Server: $dataReceived');
    var message = serializer.decode(dataReceived);
    if (!transport.isActive && message.event == 'AuthOk'){
        _handleAuthResponse(message);
    } else if(message.event == ':hb' && message.correlation_id == transport.pendingHeartbeatRef){
        _handleCleanHeartBeat(message);
    } else if(message.event == ':new_tkn'){
        _handleNewToken(message);
    } else if (transport.isActive){
        _handleUserMessage(message);
    } else {
        log.warning('Unexpected message: ${message.toString()}');
    }
  }

  void _handleAuthResponse(ChannelMessage message) {
    transport.isActive = true;
    reconnectTimer.reset();
    log.info('Change active to true!');
  }

  void _handleCleanHeartBeat(ChannelMessage message) {
    transport.pendingHeartbeatRef = null;
  }

  /// Function to handle the refreshed channel secret refresed by the server
  ///
  void _handleNewToken(ChannelMessage message) {
    actualToken = message.payload;
    log.fine('new_tkn: $actualToken');
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

  void _onTransportClose(int code) {
    if (!transport.closeWasClean && code != 4403) {
      log.severe('Transport not closed cleanly, Scheduling reconnect...');
      reconnectTimer.schedule();
    }
  }

}