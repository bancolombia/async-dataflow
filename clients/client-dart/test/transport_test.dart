import 'dart:async';
import 'dart:io';

import 'package:channel_sender_client/src/channel_message.dart';
import 'package:channel_sender_client/src/transport.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:logging/logging.dart';
import 'package:web_socket_channel/io.dart';

class MockStream extends Mock implements Stream {}

void main() {


  group('Transport Tests', () {
    HttpServer server;

    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      print('${record.level.name}: (${record.loggerName}) ${record.time}: ${record.message}');
    });

    final _log = Logger('TransportTest');

    test('Should send/receive auth and heartbeat', () async {

      server = await HttpServer.bind('localhost', 0);
      addTearDown(server.close);
      server.transform(WebSocketTransformer()).listen((WebSocket webSocket) {
        final channel = IOWebSocketChannel(webSocket);
        channel.stream.listen((request) {
          _log.finest('--> server received: $request');
          if (request == 'Auth::SFMy') {
            channel.sink.add('["", "", "AuthOk", ""]');
          } else {
            var parts = request.split('::');
            channel.sink.add('["", "${parts[1]}", ":hb", ""]');
          }
          // channel.sink.close(5678, 'raisin');
        });
      });
      
      var _headers = <String, dynamic>{};
        _headers['Connection'] = 'upgrade';
        _headers['Upgrade'] = 'websocket';
        _headers['sec-websocket-version'] = '13';
        _headers['sec-websocket-protocol'] = 'json_flow';
        _headers['sec-websocket-key'] = 'x3JJHMbDL1EzLkh9GBhXDw==';

      final webSocket = await WebSocket.connect('ws://localhost:${server.port}', 
        protocols: ['json_flow'],
        headers: _headers);
      final channel = IOWebSocketChannel(webSocket);

      late StreamController<ChannelMessage> _localStream;

      _localStream = StreamController(onListen: () {
        _log.finest('OnListen');
      });

      var _signalSocketCloseFn = (int code, String reason) {
        _log.finest('socket closed');
      };
      var _signalSocketErrorFn = (error) {
        _log.severe('socket error');
      };

      var transport = Transport(channel, _localStream, _signalSocketCloseFn, _signalSocketErrorFn, 1000);

      expect(transport, isNotNull);
      expect(transport.isOpen(), true);
      var hbCounter;

      _localStream.stream.listen((message) {
        _log.fine('Received $message');
        if (message.event == 'AuthOk') {
          transport.resetHeartbeat();
        } else if (message.event == ':hb') {
          hbCounter = message.correlationId;
          transport.pendingHeartbeatRef = null;
        }
      }, onError: (error, stacktrace) {
        _log.severe(error);
      }, onDone: () {
        _log.warning('Subscription for "xxxx" terminated.');
      });

      var sub1 = transport.subscribe(cancelOnErrorFlag: false);

      transport.send('Auth::SFMy');

      await Future.delayed(Duration(seconds: 3));

      expect(hbCounter, equals('2'));
      await sub1.cancel();

    });

  });
}