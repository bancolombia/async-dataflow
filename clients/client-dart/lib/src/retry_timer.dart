import 'dart:async';
import 'utils.dart';
import 'package:logging/logging.dart';

class RetryTimer {

    final log = Logger('RetryTimer');

    int initialWait = 100;
    int maxWait = 6000;
    Function jitterFn;
    int _defaultJitterFn(int num) => Utils.jitter(num, 0.25);
    int tries = 1;
    Future Function() function;
    Timer timer;

    RetryTimer(Future Function() function, [int initialWait, int maxWait, Function jitterFn]) {
      if (initialWait != null) {
        this.initialWait = initialWait;
      }
      if (maxWait != null) {
        this.maxWait = maxWait;
      }
      if (jitterFn == null) {
        this.jitterFn = _defaultJitterFn;
      } else {
        this.jitterFn = jitterFn;
      }
      this.function = function;
    }
    
    void reset() {
      tries = 1;
      if (timer != null) {
        timer.cancel();
        timer = null;
      }
      log.fine('Retry timer reset');
    }

    void schedule() {
      var delay = _delay();
      timer = Timer(Duration(milliseconds: delay), () async {
        try {
          await function();
        } catch (e) {
          log.severe('Captured error calling delayed function: $e');
          rethrow;
        }
      });
      log.fine('Retry timer scheduled. Due in $delay ms. Retry #$tries');
    }

    int _delay() {
      var delay = Utils.expBackoff(initialWait, maxWait, tries, _defaultJitterFn);
      tries = tries + 1;
      return delay;
    }
}