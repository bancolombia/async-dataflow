
import 'package:test/test.dart';

import 'package:channel_dart_client/src/retry_timer.dart';
import 'package:logging/logging.dart';

void main() {
    group('Retry Timer tests', () {
  
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen((record) {
        print('${record.level.name}: ${record.time}: ${record.message}');
      });
    
      test('Should retry with exponential delay', () async {
        // var times = [];
        // var counter = 0;
        // var lastTime = DateTime.now();

        Future doSomething() async {
          print('Function called');
          throw 'Some error';
        };

        var retyTimer = RetryTimer(doSomething);

        retyTimer.schedule();
        await Future.delayed(Duration(milliseconds: 2000));
        retyTimer.schedule();
        await Future.delayed(Duration(milliseconds: 3000));
        retyTimer.schedule();
        await Future.delayed(Duration(milliseconds: 4000));


        // const exp = [ 10, 20, 40, 80, 160, 320, 640 ];
        // times.forEach((delay, index) => assert.approximately(delay, exp[index], 10))

      });
  });
}