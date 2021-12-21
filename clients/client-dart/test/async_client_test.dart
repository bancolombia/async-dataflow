import 'package:channel_dart_client/src/transport.dart';
import 'package:test/test.dart';
import 'package:logging/logging.dart';
import 'package:mockito/mockito.dart';
import 'package:channel_dart_client/src/async_client.dart';
import 'package:channel_dart_client/src/async_config.dart';
import 'package:channel_dart_client/src/channel_message.dart';

class MockTransport extends Mock implements Transport {}

void main() {

    group('Async Client Tests', () {
    
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen((record) {
        print('${record.level.name}: ${record.time}: ${record.message}');
      });

      test('Simple test', () async {

        var conf = AsyncConfig();
        conf.socket_url = 'ws://localhost:8082/ext/socket';
        // conf.enable_binary_transport = true;
        conf.channel_ref = 'dummy_ref';
        conf.channel_secret = 'dummy_secret';

        var client = AsyncClient(conf);

        await client.connect();
        print('Done connecting');
        void testCallback(ChannelMessage message) {
           print(message.toString());
           client.disconnect().then((value) => null);
        }
        client.listenEvent('some.event', callback: testCallback);

        await Future.delayed(Duration(seconds: 30));
        // await client.disconnect();
      });

      // test('Should retry with exponential delay', ()async {
      //   var times = [];
      //   var counter = 0;
      //   var lastTime = DateTime.now();
      //   var timer;

      //   timer = RetryTimer(() {
      //       var now = DateTime.now();
      //       var diff = now.difference(lastTime).inSeconds;
      //       times.add(diff);
      //       lastTime = now;
      //       counter = counter + 1;
      //       if (counter < 7) {
      //         return timer.schedule();
      //       } 
      //       else { 
      //         return 0;
      //       }
      //   }, 10, (x) => x );

      //   Future<void> doSomething() async {

      //   };

      //   timer.schedule();

      //   var result = await doSomething;

      //   // const exp = [ 10, 20, 40, 80, 160, 320, 640 ];
      //   // times.forEach((delay, index) => assert.approximately(delay, exp[index], 10))

      // });
  });
}