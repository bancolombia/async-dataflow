import 'src/async_client.dart';
import 'src/async_config.dart';
import 'src/channel_message.dart';
import 'package:logging/logging.dart';

void main(List<String> arguments) async {

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  var conf = AsyncConfig();
  conf.socket_url = 'ws://localhost:8082/ext/socket';
  conf.enable_binary_transport = true;
  conf.channel_ref = '<channel_ref>';
  conf.channel_secret = '<secret>';
  conf.heartbeat_interval = 2500;
  
  var client = AsyncClient(conf);
  var state = await client.connect();

  if (state == true) {
    void testCallback(ChannelMessage message) => print(message.payload);
    client.listenEvent('event.productCreated', callback: testCallback);
  }

  // await Future.delayed(Duration(seconds: 90));
  // await client.disconnect();
}
