import 'package:channel_sender_client/src/utils/retry_timer.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  group('Retry Timer tests', () {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // ignore: avoid_print
      print('${record.level.name}: ${record.time}: ${record.message}');
    });

    test('Should retry with exponential delay', () async {
      var doSomething = () async {
        Logger.root.info('Dummy function called');
        throw ArgumentError('Some error');
      };
      var doSomethingElse = () async {
        Logger.root.info('Dummy function called');
        throw ArgumentError('Some error');
      };

      var retyTimer = RetryTimer(doSomething, doSomethingElse);

      retyTimer.schedule();
      await Future.delayed(const Duration(milliseconds: 2000));
      retyTimer.schedule();
      await Future.delayed(const Duration(milliseconds: 3000));
      retyTimer.schedule();
      await Future.delayed(const Duration(milliseconds: 4000));
    });

    test('Should retry with exponential delay, custom params', () async {
      var doSomething = () async {
        Logger.root.info('Dummy function called');
        throw ArgumentError('Some error');
      };

      var customJitter = (int num) {
        return 1;
      };
      var doSomethingElse = () async {
        Logger.root.info('Dummy function called');
        throw ArgumentError('Some error');
      };

      var retyTimer = RetryTimer(doSomething, doSomethingElse,
          initialWait: 100, maxWait: 300, jitterFn: customJitter);

      retyTimer.schedule();
      await Future.delayed(const Duration(milliseconds: 500));
      retyTimer.schedule();
      await Future.delayed(const Duration(milliseconds: 500));
      retyTimer.schedule();
      await Future.delayed(const Duration(milliseconds: 500));
    });

    test('Should cancel retry timer', () async {
      var doSomething = () async {
        Logger.root.info('Dummy function called');
        throw ArgumentError('Some error');
      };
      var doSomethingElse = () async {
        Logger.root.info('Dummy function called');
        throw ArgumentError('Some error');
      };

      var retyTimer = RetryTimer(doSomething, doSomethingElse);

      retyTimer.schedule();
      await Future.delayed(const Duration(milliseconds: 500));

      retyTimer.reset();
    });
  });
}
