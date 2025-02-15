import 'dart:io';

import 'package:channel_sender_client/src/async_client.dart';
import 'package:channel_sender_client/src/async_config.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

void main() {
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
        channel.stream.listen((request) {
          log.finest('--> server received: $request');
          if (request.startsWith('Auth')) {
            channel.sink.add('["", "", "AuthOk", ""]');
          } else if (request.startsWith('hb')) {
            var parts = request.split('::');
            channel.sink.add('["", "${parts[1]}", ":hb", ""]');
          } else {
            channel.sink.close(5678, 'raisin');
          }
        });
      });

      var conf = AsyncConfig(
          socketUrl: 'ws://localhost:${server.port}',
          channelRef: 'xxx-channel-ref-xxxx',
          channelSecret: 'xxx-channel-secret-xxx',
          enableBinaryTransport: false,
          heartbeatInterval: 1000);

      var client = AsyncClient(conf).connect();

      log.finest('------ Done connecting -------');

      var subscriber = client.subscribeTo('event.productCreated', (event) {
        log.info('SUB 1 JUST RECEIVED: $event');
      }, onError: (err) {
        log.severe('SUB 1 JUST RECEIVED AN ERROR: $err');
      });

      await Future.delayed(const Duration(seconds: 2));

      await subscriber.cancel();
      await client.disconnect();
    });
  });
}
