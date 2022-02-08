import 'src/async_client.dart';
import 'src/async_config.dart';
import 'package:logging/logging.dart';

void main(List<String> arguments) async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  var conf = AsyncConfig(
      socketUrl: 'ws://localhost:8082/ext/socket',
      enableBinaryTransport: false,
      channelRef:
          'fbe11e942bbf3deda0c0279813e583e1.87a0fb6b162441428e1883e4e4121b04',
      channelSecret:
          'SFMyNTY.g2gDaANtAAAAQWZiZTExZTk0MmJiZjNkZWRhMGMwMjc5ODEzZTU4M2UxLjg3YTBmYjZiMTYyNDQxNDI4ZTE4ODNlNGU0MTIxYjA0bQAAAB1VTklRVUUgQVBQTElDQVRJT04gSURFTlRJRklFUm0AAAALVVNFUkBET01BSU5uBgBTYPIifgFiAAFRgA.xSX5UZTGeINsFcNbIq0ySHPOYlzSrKyGIjjk8NKUOVE',
      heartbeatInterval: 2500);

  var client = AsyncClient(conf).connect();

  client.subscribeTo('event.productCreated', (event) {
    print('SUB 1 JUST RECEIVED: $event');
  }, onError: (err) {
    print('SUB 1 JUST RECEIVED AN ERROR: $err');
  });

  client.subscribeTo('event.productCreated', (event) {
    print('SUB 2 JUST RECEIVED: $event');
  }, onError: (err) {
    print('SUB 2 JUST RECEIVED AN ERROR: $err');
  });

  await Future.delayed(Duration(seconds: 10));
  await client.disconnect();
}
