import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:channel_sender_client/channel_sender_client.dart';
import 'package:channel_sender_client/src/transport/ws_transport.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

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

    test('Should connect and disconnect', () async {
      server = await HttpServer.bind('localhost', 8686);
      addTearDown(server.close);

      server.transform(WebSocketTransformer()).listen((WebSocket serverSocket) {
        serverSocket.listen((request) {});
      });

      var signalSocketCloseFn = (int code, String reason) {
        log.finest('socket closed');
      };
      var signalSocketErrorFn = (error) {
        log.severe('socket error');
      };

      AsyncConfig config = AsyncConfig(
          socketUrl: 'ws://localhost:${server.port}',
          channelRef: 'channelRef',
          channelSecret: 'SFMy',
          heartbeatInterval: 1000,);

      var transport =
          WSTransport(signalSocketCloseFn, signalSocketErrorFn, config);

      expect(await transport.connect(), true);

      await transport.disconnect();

    });

    test('Should send/receive auth and heartbeat', () async {
      server = await HttpServer.bind('localhost', 8686);
      addTearDown(server.close);

      server.transform(WebSocketTransformer()).listen((WebSocket serverSocket) {
        serverSocket.listen((request) {
          if (request == 'Auth::SFMy') {
            serverSocket.add('["", "", "AuthOk", ""]');
          } else {
            var parts = request.split('::');
            serverSocket.add('["", "${parts[1]}", ":hb", ""]');
          }
        });
      });

      var headers = <String, dynamic>{};
      headers['Connection'] = 'upgrade';
      headers['Upgrade'] = 'websocket';
      headers['sec-websocket-version'] = '13';
      headers['sec-websocket-protocol'] = 'json_flow';
      headers['sec-websocket-key'] = 'x3JJHMbDL1EzLkh9GBhXDw==';

      // final clientSocket = await WebSocket.connect('ws://localhost:${server.port}',
      //     protocols: ['json_flow'], headers: headers);

      var signalSocketCloseFn = (int code, String reason) {
        log.finest('socket closed');
      };
      var signalSocketErrorFn = (error) {
        log.severe('socket error');
      };

      AsyncConfig config = AsyncConfig(
          socketUrl: 'ws://localhost:${server.port}',
          channelRef: 'channelRef',
          channelSecret: 'SFMy',
          heartbeatInterval: 1000,);

      var transport =
          WSTransport(signalSocketCloseFn, signalSocketErrorFn, config);

      String? hbCounter;

      await transport.connect();

      // transport.webSocketCh = clientSocket;
      expect(transport, isNotNull);
      expect(transport.isOpen(), true);

      transport.stream.listen((message) {
        log.fine('<-- client received : $message');
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
      
      // transport.send('Auth::SFMy');

      await Future.delayed(const Duration(seconds: 3));
      // expect(hbCounter, equals('2'));

      await transport.disconnect();
    });

    test('Should handle new token', () async {
      server = await HttpServer.bind(
        'localhost',
        8686,
      );
      addTearDown(server.close);
      server.transform(WebSocketTransformer()).listen((WebSocket channel) {
        
        channel.listen((request) {
          log.finest('--> server received: $request');
          if (request == 'newToken') {
            channel.add('["", "", ":n_token", "abc123"]');
          } else {
            var parts = request.split('::');
            channel.add('["", "${parts[1]}", ":hb", ""]');
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
          heartbeatInterval: 1000,);

      var transport =
          WSTransport(signalSocketCloseFn, signalSocketErrorFn, config);

      await transport.connect();

      transport.stream.listen(
        (event) {},
      );

      expect(transport, isNotNull);

      transport.send('newToken');

      await Future.delayed(const Duration(seconds: 1));

      expect(transport.currentToken, equals('abc123'));

      await transport.disconnect();
    });

    test('Should handle socket DONE signal and retries', () async {
      server = await HttpServer.bind(
        'localhost',
        8686,
      );
      addTearDown(server.close);

      server.transform(WebSocketTransformer()).listen((WebSocket channel) {
        channel.listen((request) async {
          await Future.delayed(Duration(milliseconds: 200), () {
            // final error = Exception('This is a test error');
            // final stackTrace = StackTrace.current;
            channel.close(1002, 'Test error');
          });
        });
      });

      var signalSocketCloseFn = (int code, String reason) {
        log.finest('socket closed');
      };

      bool onErrorCalled = false;
      var signalSocketErrorFn = (error) {
        log.severe('socket error');
        assert(error.message == 'Max retries reached');
        onErrorCalled = true;
      };

      AsyncConfig config = AsyncConfig(
          socketUrl: 'ws://localhost:8686',
          channelRef: 'channelRef',
          channelSecret: 'channelSecret',
          maxRetries: 2,
          heartbeatInterval: 1000,);

      var transport =
          WSTransport(signalSocketCloseFn, signalSocketErrorFn, config);

      expect(await transport.connect(), true);

      await Future.delayed(const Duration(seconds: 2));

      expect(onErrorCalled, true);
    });

  });
}
