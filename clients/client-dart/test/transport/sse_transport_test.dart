import 'dart:async';
import 'dart:io';

import 'package:channel_sender_client/channel_sender_client.dart';
import 'package:channel_sender_client/src/transport/types/sse_transport.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;

  setUp(() async {
    // mockHttpClient = MockHttpClient();
    server = await HttpServer.bind(
      'localhost',
      8787,
    );
    addTearDown(server.close);
  });

  group('SSE Transport Tests', () {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // ignore: avoid_print
      print(
        '${record.level.name}: (${record.loggerName}) ${record.time}: ${record.message}',
      );
    });

    final log = Logger('SSE TransportTest');

    test('Should connect with server', () async {
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

      bool connected = await transport.connect();

      expect(connected, true);

      expect(transport, isNotNull);

      await Future.delayed(const Duration(seconds: 3));

      expect(transport.currentToken, equals('channelSecret'));

      await transport.disconnect();
    });

    test('Should get new token', () async {
      server.listen((HttpRequest request) {
        if (request.uri.path == '/ext/sse') {
          request.response.headers.contentType =
              ContentType('text', 'event-stream', charset: 'utf-8');
          request.response.headers.add('Cache-Control', 'no-cache');
          request.response.headers.add('Connection', 'keep-alive');
          request.response
              .write('data: ["", "", ":n_token", "new_secret"]\n\n');
          request.response.close();
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.close();
        }
      });

      var signalSocketCloseFn = (int code, String reason) {
        log.finest('socket closed');
      };
      var signalSocketErrorFn = (error) {
        log.severe('socket error');
      };

      AsyncConfig config = AsyncConfig(
        socketUrl: 'ws://localhost:8787/ext/socket',
        sseUrl: 'http://localhost:8787/ext/sse',
        channelRef: 'channelRef',
        channelSecret: 'channelSecret',
        maxRetries: 3,
        heartbeatInterval: 1000,
        transportsProvider: [TransportType.sse],
      );

      var transport =
          SSETransport(signalSocketCloseFn, signalSocketErrorFn, config);

      await transport.connect();
      transport.stream.listen((event) {
        log.info('event: $event');
        if (event.event == ':n_token') {
          transport.currentToken = event.payload;
        }
      });

      await Future.delayed(const Duration(seconds: 2));

      expect(transport, isNotNull);

      expect(transport.currentToken, equals('new_secret'));
      await transport.disconnect();
    });

    //   test('Should get error', () async {
    //     final controller = StreamController<SSEModel>();

    //     final stream = controller.stream;
    //     for (int i = 1; i <= 11; i++) {
    //       controller.addError('error $i');
    //     }

    //     var signalSocketCloseFn = (int code, String reason) {
    //       log.finest('sse closed');
    //     };
    //     var signalSocketErrorFn = (error) {
    //       log.severe('sse error');
    //     };
    //     AsyncConfig config = AsyncConfig(
    //         socketUrl: 'ws://localhost:8787',
    //         channelRef: 'channelRef',
    //         channelSecret: 'channelSecret',
    //         heartbeatInterval: 1000);

    //     var transport =
    //         SSETransport(signalSocketCloseFn, signalSocketErrorFn, config);
    //     transport.eventSource = stream;

    //     await transport.connect();
    //     transport.stream.listen((event) {
    //       log.info('event: $event');
    //     });
    //     await Future.delayed(const Duration(seconds: 10));
    //     expect(transport, isNotNull);

    //     await transport.disconnect();

    //     await controller.close();
    //   });
  });
}
