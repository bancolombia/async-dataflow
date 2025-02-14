import 'dart:async';
import 'dart:io';

import 'package:channel_sender_client/channel_sender_client.dart';
import 'package:channel_sender_client/src/transport/ws_transport.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  group('WS Transport Tests', () {
    HttpServer server;

    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // ignore: avoid_print
      print(
        '${record.level.name}: (${record.loggerName}) ${record.time}: ${record.message}',
      );
    });

    final log = Logger('WS TransportTest');

    test('Should send/receive auth and heartbeat', () async {
      server = await HttpServer.bind('localhost', 8686);
      addTearDown(server.close);
      server.transform(WebSocketTransformer()).listen((WebSocket webSocket) {
        final channel = IOWebSocketChannel(webSocket);

        channel.stream.listen((request) {
          log.finest('--> server received: $request');
          if (request == 'Auth::SFMy') {
            channel.sink.add('["", "", "AuthOk", ""]');
          } else {
            var parts = request.split('::');
            channel.sink.add('["", "${parts[1]}", ":hb", ""]');
          }
        });
      });

      var headers = <String, dynamic>{};
      headers['Connection'] = 'upgrade';
      headers['Upgrade'] = 'websocket';
      headers['sec-websocket-version'] = '13';
      headers['sec-websocket-protocol'] = 'json_flow';
      headers['sec-websocket-key'] = 'x3JJHMbDL1EzLkh9GBhXDw==';

      final webSocket = await WebSocket.connect('ws://localhost:${server.port}',
          protocols: ['json_flow'], headers: headers);
      final channel = IOWebSocketChannel(webSocket);

      late StreamController<ChannelMessage> localStream;

      localStream = StreamController(onListen: () {
        log.finest('OnListen');
      });

      var signalSocketCloseFn = (int code, String reason) {
        log.finest('socket closed');
      };
      var signalSocketErrorFn = (error) {
        log.severe('socket error');
      };
      AsyncConfig config = AsyncConfig(
          socketUrl: 'ws://localhost:8082',
          channelRef: 'channelRef',
          channelSecret: 'channelSecret',
          heartbeatInterval: 1000);

      var transport =
          WSTransport(signalSocketCloseFn, signalSocketErrorFn, config);
      String? hbCounter;

      localStream.stream.listen((message) {
        log.fine('Received $message');
        if (message.event == 'AuthOk') {
          transport.resetHeartbeat();
        } else if (message.event == ':hb') {
          hbCounter = message.correlationId;
          transport.pendingHeartbeatRef = null;
        }
      }, onError: (error, stacktrace) {
        log.severe(error);
      }, onDone: () {
        log.warning('Subscription for "xxxx" terminated.');
      });
      transport.webSocketCh = channel;
      transport.localStream = localStream;

      expect(transport, isNotNull);
      expect(transport.isOpen(), true);

      var sub1 = transport.subscribe(cancelOnErrorFlag: false);

      transport.send('Auth::SFMy');

      await Future.delayed(const Duration(seconds: 3));
      expect(hbCounter, equals('2'));

      await transport.disconnect();
    });

    test('Should handle new token', () async {
      server = await HttpServer.bind(
        'localhost',
        8686,
      );
      addTearDown(server.close);
      server.transform(WebSocketTransformer()).listen((WebSocket webSocket) {
        final channel = IOWebSocketChannel(webSocket);

        channel.stream.listen((request) {
          log.finest('--> server received: $request');
          if (request == 'newToken') {
            channel.sink.add('["", "", ":n_token", "abc123"]');
          } else {
            var parts = request.split('::');
            channel.sink.add('["", "${parts[1]}", ":hb", ""]');
          }
        });
      });

      var headers = <String, dynamic>{};
      headers['Connection'] = 'upgrade';
      headers['Upgrade'] = 'websocket';
      headers['sec-websocket-version'] = '13';
      headers['sec-websocket-protocol'] = 'json_flow';
      headers['sec-websocket-key'] = 'x3JJHMbDL1EzLkh9GBhXDw==';

      var signalSocketCloseFn = (int code, String reason) {
        log.finest('socket closed');
      };
      var signalSocketErrorFn = (error) {
        log.severe('socket error');
      };
      AsyncConfig config = AsyncConfig(
          socketUrl: 'ws://localhost:8686',
          channelRef: 'channelRef',
          channelSecret: 'channelSecret',
          heartbeatInterval: 1000);

      var transport =
          WSTransport(signalSocketCloseFn, signalSocketErrorFn, config);
      transport.connect();
      transport.stream.listen(
        (event) {},
      );

      expect(transport, isNotNull);

      transport.send('newToken');

      await Future.delayed(const Duration(seconds: 1));

      expect(transport.currentToken, equals('abc123'));

      await transport.disconnect();
    });
  });
}
