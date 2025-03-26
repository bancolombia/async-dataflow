import 'dart:async';
import 'dart:io';

import 'package:channel_sender_client/channel_sender_client.dart';
import 'package:channel_sender_client/src/transport/sse_transport.dart';
import 'package:client_sse/flutter_client_sse.dart';
import 'package:logging/logging.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class MockStream extends Mock implements Stream {}

void main() {
  group('SSE Transport Tests', () {
    HttpServer server;

    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // ignore: avoid_print
      print(
        '${record.level.name}: (${record.loggerName}) ${record.time}: ${record.message}',
      );
    });

    final log = Logger('SSE TransportTest');

    test('Should connect with server', () async {
      server = await HttpServer.bind(
        'localhost',
        8787,
      );
      addTearDown(server.close);
      server.listen((HttpRequest request) {});

      var signalSocketCloseFn = (int code, String reason) {
        log.finest('socket closed');
      };
      var signalSocketErrorFn = (error) {
        log.severe('socket error');
      };
      AsyncConfig config = AsyncConfig(
          socketUrl: 'ws://localhost:8787',
          channelRef: 'channelRef',
          channelSecret: 'channelSecret',
          heartbeatInterval: 1000);

      var transport =
          SSETransport(signalSocketCloseFn, signalSocketErrorFn, config);
      await transport.connect();
      transport.stream.listen(
        (event) {},
      );

      expect(transport, isNotNull);

      await Future.delayed(const Duration(seconds: 3));

      expect(transport.currentToken, equals('channelSecret'));

      await transport.disconnect();
    });

    test('Should get new token', () async {
      final controller = StreamController<SSEModel>();

      final stream = controller.stream;

      for (int i = 1; i <= 5; i++) {
        controller.add(SSEModel(
            data: '["", "", "AuthOk", ""]', id: '$i', event: 'event $i'));
      }
      controller.add(SSEModel(
          data: '["", "", ":n_token", "abc123"]',
          id: '1000',
          event: 'event 1000'));

      var signalSocketCloseFn = (int code, String reason) {
        log.finest('socket closed');
      };
      var signalSocketErrorFn = (error) {
        log.severe('socket error');
      };
      AsyncConfig config = AsyncConfig(
          socketUrl: 'ws://localhost:8787',
          channelRef: 'channelRef',
          channelSecret: 'channelSecret',
          heartbeatInterval: 1000);

      var transport =
          SSETransport(signalSocketCloseFn, signalSocketErrorFn, config);
      transport.eventSource = stream;

      await transport.connect();
      transport.stream.listen((event) {
        log.info('event: $event');
      });
      await Future.delayed(const Duration(seconds: 10));
      expect(transport, isNotNull);

      expect(transport.currentToken, equals('abc123'));
      await transport.disconnect();

      await controller.close();
    });

    test('Should get error', () async {
      final controller = StreamController<SSEModel>();

      final stream = controller.stream;
      for (int i = 1; i <= 11; i++) {
        controller.addError('error $i');
      }

      var signalSocketCloseFn = (int code, String reason) {
        log.finest('sse closed');
      };
      var signalSocketErrorFn = (error) {
        log.severe('sse error');
      };
      AsyncConfig config = AsyncConfig(
          socketUrl: 'ws://localhost:8787',
          channelRef: 'channelRef',
          channelSecret: 'channelSecret',
          heartbeatInterval: 1000);

      var transport =
          SSETransport(signalSocketCloseFn, signalSocketErrorFn, config);
      transport.eventSource = stream;

      await transport.connect();
      transport.stream.listen((event) {
        log.info('event: $event');
      });
      await Future.delayed(const Duration(seconds: 10));
      expect(transport, isNotNull);

      await transport.disconnect();

      await controller.close();
    });
  });
}
