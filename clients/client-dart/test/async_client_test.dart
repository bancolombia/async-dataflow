import 'package:channel_dart_client/src/transport.dart';
import 'package:mockito/annotations.dart';
import 'package:test/test.dart';
import 'package:logging/logging.dart';
import 'package:channel_dart_client/src/async_client.dart';
import 'package:channel_dart_client/src/async_config.dart';
import 'package:web_socket_channel/io.dart';

import 'async_client_test.mocks.dart';

@GenerateMocks([IOWebSocketChannel, Transport])
void main() {

      var transportMock = MockTransport();
      var webSocketMock = MockIOWebSocketChannel();
      
      group('Async Client Tests', () {
    
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen((record) {
        print('${record.level.name}: ${record.time}: ${record.message}');
      });

      test('Simple test', () async {

        var conf = AsyncConfig();
        conf.socket_url = 'ws://localhost:8082/ext/socket';
        conf.channel_ref = 'dummy_ref';
        conf.channel_secret = 'dummy_secret';

        var client = AsyncClient(conf).connect();
        
        print('Done connecting');

        var subscriber = client.subscribeTo('event.productCreated', (event) {
          print('SUB 1 JUST RECEIVED: $event');
        }, onError: (err) {
          print('SUB 1 JUST RECEIVED AN ERROR: $err');
        });

        await subscriber.cancel();

        await client.disconnect();

        await Future.delayed(Duration(seconds: 30));
        // await client.disconnect();
      });
      
  });
}