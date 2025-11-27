import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:channel_sender_client/channel_sender_client.dart';
import 'package:channel_sender_client/src/transport/types/ws_transport.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockAsyncConfig extends Mock implements AsyncConfig {}

class MockWebSocket extends Mock implements WebSocket {}

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
        heartbeatInterval: 1000,
      );

      var transport = WSTransport(
        signalSocketCloseFn,
        signalSocketErrorFn,
        config,
      );

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
        heartbeatInterval: 1000,
      );

      var transport = WSTransport(
        signalSocketCloseFn,
        signalSocketErrorFn,
        config,
      );

      String? hbCounter;

      await transport.connect();

      // transport.webSocketCh = clientSocket;
      expect(transport, isNotNull);
      expect(transport.isOpen(), true);

      transport.stream.listen(
        (message) {
          log.fine('<-- client received : $message');
          if (message.event == 'AuthOk') {
            transport.resetHeartbeat();
          } else if (message.event == ':hb') {
            hbCounter = message.correlationId;
            transport.pendingHeartbeatRef = null;
          }
        },
        onError: (error, stacktrace) {
          log.severe(error);
        },
        onDone: () {
          log.warning('Subscription for "xxxx" terminated.');
        },
      );

      // transport.send('Auth::SFMy');

      await Future.delayed(const Duration(seconds: 3));
      // expect(hbCounter, equals('2'));

      await transport.disconnect();
    });

    test('Should handle new token', () async {
      server = await HttpServer.bind('localhost', 8686);
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
        heartbeatInterval: 1000,
      );

      var transport = WSTransport(
        signalSocketCloseFn,
        signalSocketErrorFn,
        config,
      );

      await transport.connect();

      transport.stream.listen((event) {});

      expect(transport, isNotNull);

      transport.send('newToken');

      await Future.delayed(const Duration(seconds: 1));

      expect(transport.currentToken, equals('abc123'));

      await transport.disconnect();
    });

    test('Should handle socket DONE signal and retries', () async {
      server = await HttpServer.bind('localhost', 8686);
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
        heartbeatInterval: 1000,
      );

      var transport = WSTransport(
        signalSocketCloseFn,
        signalSocketErrorFn,
        config,
      );

      expect(await transport.connect(), true);

      await Future.delayed(const Duration(seconds: 2));

      expect(onErrorCalled, true);
    });
  });

  group('WSTransport Deduplication', () {
    late WSTransport transport;
    late MockAsyncConfig mockConfig;
    late MockWebSocket mockWebSocket;
    late StreamController<dynamic> socketStreamController;

    setUp(() {
      mockConfig = MockAsyncConfig();
      mockWebSocket = MockWebSocket();
      socketStreamController = StreamController<dynamic>();

      when(() => mockConfig.channelSecret).thenReturn('secret');
      when(() => mockConfig.channelRef).thenReturn('ref');
      when(() => mockConfig.socketUrl).thenReturn('ws://localhost');
      when(() => mockConfig.enableBinaryTransport).thenReturn(false);
      when(() => mockConfig.maxRetries).thenReturn(3);
      when(() => mockConfig.hbInterval).thenReturn(30000);

      when(() => mockWebSocket.readyState).thenReturn(WebSocket.open);
      when(
        () => mockWebSocket.listen(
          any(),
          onError: any(named: 'onError'),
          onDone: any(named: 'onDone'),
          cancelOnError: any(named: 'cancelOnError'),
        ),
      ).thenAnswer((invocation) {
        return socketStreamController.stream.listen(
          invocation.positionalArguments[0] as void Function(dynamic),
          onError: invocation.namedArguments[#onError] as Function?,
          onDone: invocation.namedArguments[#onDone] as void Function()?,
          cancelOnError: invocation.namedArguments[#cancelOnError] as bool?,
        );
      });

      when(() => mockWebSocket.add(any())).thenReturn(null);

      when(
        () => mockWebSocket.close(any(), any()),
      ).thenAnswer((_) async => null);
      when(() => mockWebSocket.close()).thenAnswer((_) async => null);
      when(() => mockWebSocket.closeCode).thenReturn(1000);
      when(() => mockWebSocket.closeReason).thenReturn('Normal Closure');

      transport = WSTransport((code, reason) {}, (error) {}, mockConfig);

      transport.webSocketCh = mockWebSocket;
    });

    tearDown(() {
      socketStreamController.close();
    });

    test('should deduplicate messages with same messageId', () async {
      final receivedMessages = <ChannelMessage>[];
      final subscription = transport.stream.listen((msg) {
        receivedMessages.add(msg);
      });

      transport.subscribe(cancelOnErrorFlag: false);

      // Create two identical messages (same ID)
      final frame1 = jsonEncode(['msg-123', 'test-event', '', 'data-1']);
      final frame2 = jsonEncode(['msg-123', 'test-event', '', 'data-2']);

      socketStreamController.add(frame1);

      await Future.delayed(Duration(milliseconds: 50));

      socketStreamController.add(frame2);

      await Future.delayed(Duration(milliseconds: 50));

      expect(
        receivedMessages.length,
        equals(1),
        reason: 'Should have received only 1 message',
      );
      expect(
        receivedMessages.first.payload,
        equals('data-1'),
        reason: 'Should be the first message',
      );

      await subscription.cancel();
    });

    test('should allow messages with different messageIds', () async {
      final receivedMessages = <ChannelMessage>[];
      transport.stream.listen((msg) => receivedMessages.add(msg));
      transport.subscribe(cancelOnErrorFlag: false);

      final frame1 = jsonEncode(['msg-A', 'event-A', '', 'data-A']);
      final frame2 = jsonEncode(['msg-B', 'event-B', '', 'data-B']);

      socketStreamController.add(frame1);
      await Future.delayed(Duration(milliseconds: 10));
      socketStreamController.add(frame2);
      await Future.delayed(Duration(milliseconds: 10));

      expect(receivedMessages.length, equals(2));
    });
  });
}
