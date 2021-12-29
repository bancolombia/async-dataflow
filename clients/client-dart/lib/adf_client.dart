import 'src/async_client.dart';
import 'src/async_config.dart';
import 'package:logging/logging.dart';

void main(List<String> arguments) async {

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  var conf = AsyncConfig();
  conf.socket_url = 'ws://localhost:8082/ext/socket';
  conf.enable_binary_transport = false;
  conf.channel_ref = '<a channel ref>';
  conf.channel_secret = '<a secret>';
  conf.heartbeat_interval = 2500;
  
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

  await Future.delayed(Duration(seconds: 90));
  await client.disconnect();
}
