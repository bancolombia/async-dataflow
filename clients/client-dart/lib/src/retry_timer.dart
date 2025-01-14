import 'dart:async';

import 'package:logging/logging.dart';

import 'utils.dart';

class RetryTimer {
  final _log = Logger('RetryTimer');

  int _initialWait = 100;
  int _maxWait = 6000;
  late Function _jitterFn;
  int _defaultJitterFn(int num) {
    var randomFactor = 0.25;

    return Utils.jitter(num, randomFactor);
  }

  int _tries = 0;
  late Future Function() _function;
  Timer? _timer;

  RetryTimer(
    Future Function() function, {
    int? initialWait,
    int? maxWait,
    Function? jitterFn,
  }) {
    _initialWait = initialWait ?? _initialWait;

    _maxWait = maxWait ?? _maxWait;

    _jitterFn = jitterFn ?? _defaultJitterFn;
    _function = function;
  }

  void reset() {
    _tries = 0;
    _timer?.cancel();
    _timer = null;
    _log.finest('Retry timer reset');
  }

  void schedule() {
    var delay = _delay();
    _timer = Timer(Duration(milliseconds: delay), () async {
      try {
        await _function();
      } catch (e) {
        _log.severe('Captured error calling delayed function: $e');
      }
    });
    _tries = _tries + 1;
    _log.fine('Retry scheduled. Due in $delay ms. Retry #$_tries');
  }

  int _delay() {
    return Utils.expBackoff(_initialWait, _maxWait, _tries, _jitterFn);
  }
}
