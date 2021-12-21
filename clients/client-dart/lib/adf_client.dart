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
  conf.socket_url = 'http://localhost:8082';
  // conf.enable_binary_transport = true;
  conf.channel_ref = '44f59ec0689f3908a0281330add5d9c7.088a7f137c1c4f5387e928a2111f8457';
  conf.channel_secret = 'SFMyNTY.g2gDaANtAAAAQTQ0ZjU5ZWMwNjg5ZjM5MDhhMDI4MTMzMGFkZDVkOWM3LjA4OGE3ZjEzN2MxYzRmNTM4N2U5MjhhMjExMWY4NDU3bQAAAA9hcHBsaWNhdGlvbl9yZWZtAAAACHVzZXJfcmVmbgYAHr4ZQ3kBYgABUYA.J8pmlTCL6dqUrDFiKtpWgwdAVnAqThmlkvFua1wMauI';

  var client = AsyncClient(conf);
  await client.connect();

  void testCallback(ChannelMessage message) => print(message.payload);
  client.listenEvent('event.productCreated', callback: testCallback);

  await Future.delayed(Duration(seconds: 90));
  await client.disconnect();
}
