import '../lib/src/async_client.dart';
import '../lib/src/async_config.dart';
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
          'd30774f110683c9db9eece36524d2d04.99621ecb9d3c4f71b69887d2c639fed0',
      channelSecret:
          'SFMyNTY.g2gDaANtAAAAQWQzMDc3NGYxMTA2ODNjOWRiOWVlY2UzNjUyNGQyZDA0Ljk5NjIxZWNiOWQzYzRmNzFiNjk4ODdkMmM2MzlmZWQwbQAAAARhcHAxbQAAAAh1c2VyX3JlZm4GAFfri3p_AWIAAVGA.dgeQR6mBXL30fm-8PuUA9YrThFJ0ieJMl8R-LcM1WOg',
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

  await Future.delayed(Duration(seconds: 30));

  await client.disconnect();
}
