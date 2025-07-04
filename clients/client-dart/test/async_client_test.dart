import 'dart:io';

import 'package:channel_sender_client/src/async_client.dart';
import 'package:channel_sender_client/src/async_config.dart';
import 'package:channel_sender_client/src/transport/transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Async Client Tests', () {
    HttpServer server;

    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // ignore: avoid_print
      print(
        '${record.level.name}: (${record.loggerName}) ${record.time}: ${record.message}',
      );
    });

    final log = Logger('AsyncClientTest');

    test('Simple test', () async {
      server = await HttpServer.bind('localhost', 0);
      addTearDown(server.close);

      server.transform(WebSocketTransformer()).listen((WebSocket webSocket) {
        final channel = IOWebSocketChannel(webSocket);
        channel.stream.listen((request) async {
          log.finest('--> server received: $request');
          if (request.startsWith('Auth')) {
            channel.sink.add('["", "", "AuthOk", ""]');

            await Future.delayed(const Duration(seconds: 1), () {
              channel.sink.add('["1", "2", "event.productCreated", "hello"]');
            });
          } else if (request.startsWith('hb')) {
            var parts = request.split('::');
            channel.sink.add('["", "${parts[1]}", ":hb", ""]');
          }
        });
      });

      var conf = AsyncConfig(
        socketUrl: 'ws://localhost:${server.port}',
        channelRef: 'xxx-channel-ref-xxxx',
        channelSecret: 'xxx-channel-secret-xxx',
        enableBinaryTransport: false,
        transportsProvider: [TransportType.ws],
        heartbeatInterval: 500,
      );

      AsyncClient client = AsyncClient(conf);
      expect(await client.connect(), true);
      expect(await client.isOpen(), true);

      log.finest('------ Done connecting -------');

      bool messageReceived = false;
      var subscriber = client.subscribeTo('event.productCreated', (event) {
        log.info('SUB 1 JUST RECEIVED: $event');
        messageReceived = true;
      }, onError: (err) {
        log.severe('SUB 1 JUST RECEIVED AN ERROR: $err');
      });

      await Future.delayed(const Duration(seconds: 3));

      expect(messageReceived, true);

      // await subscriber?.cancel();
      await client.disconnect();
    });

    test('Handle protocol switch with single transoport', () async {
      server = await HttpServer.bind('localhost', 0);
      addTearDown(server.close);

      server.transform(WebSocketTransformer()).listen((WebSocket webSocket) {
        final channel = IOWebSocketChannel(webSocket);
        channel.stream.listen((request) async {
          log.finest('--> server received: $request');
          if (request.startsWith('Auth')) {
            channel.sink.add('["", "", "AuthOk", ""]');
          } else if (request.startsWith('hb')) {
            var parts = request.split('::');
            channel.sink.add('["", "${parts[1]}", ":hb", ""]');
          }
        });
      });

      var conf = AsyncConfig(
        socketUrl: 'ws://localhost:${server.port}',
        channelRef: 'xxx-channel-ref-xxxx',
        channelSecret: 'xxx-channel-secret-xxx',
        enableBinaryTransport: false,
        transportsProvider: [TransportType.ws],
        heartbeatInterval: 500,
      );

      AsyncClient client = AsyncClient(conf);
      expect(await client.connect(), true);
      expect(await client.isOpen(), true);

      log.finest('------ Done connecting -------');

      var subscriber = client.subscribeTo('event.productCreated', (event) {
        log.info('SUB 1 JUST RECEIVED: $event');
      }, onError: (err) {
        log.severe('SUB 1 JUST RECEIVED AN ERROR: $err');
      });

      await Future.delayed(const Duration(seconds: 1));

      expect(await client.switchProtocols(), false);

      await Future.delayed(const Duration(seconds: 1));

      // await subscriber?.cancel();
      await client.disconnect();
    });
  });
}
