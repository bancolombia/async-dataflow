import 'dart:async';

import 'package:logging/logging.dart';

import 'utils.dart';

class RetryTimer {
  final _log = Logger('RetryTimer');

  late final Function _jitterFn;
  int _initialWait = 50;
  int _maxWait = 6000;
  int _maxRetries = 10;
  int _defaultJitterFn(int num) {
    var randomFactor = 0.25;

    return Utils.jitter(num, randomFactor);
  }

  int _tries = 0;
  late Future Function() _callback;
  late Future Function() _limitReachedCallback;

  Timer? _timer;

  RetryTimer(
    Future Function() callback,
    Future Function() limitReachedCallback, {
    int? initialWait,
    int? maxWait,
    Function? jitterFn,
    int? maxRetries,
  }) {
    _initialWait = initialWait ?? _initialWait;
    _maxWait = maxWait ?? _maxWait;
    _maxRetries = maxRetries ?? _maxRetries;
    _jitterFn = jitterFn ?? _defaultJitterFn;
    _callback = callback;
    _limitReachedCallback = limitReachedCallback;
  }

  void reset() {
    _tries = 0;
    _timer?.cancel();
    _timer = null;
    _log.finest('[async-client][RetyTimer] Retry timer reset');
  }

  bool isActive() {
    return _timer?.isActive ?? false;
  }

  void schedule() {
    if (_timer?.isActive ?? false) {
      _log.finest('[async-client][RetyTimer] Timer already active, skipping scheduling');
      
      return;
    }
    var delay = _delay();
    _log.info('[async-client][RetyTimer] scheduling retry in $delay ms');
    _timer = Timer(Duration(milliseconds: delay), () async {
      try {
        if (_tries <= _maxRetries) {
          _log.info('[async-client][RetyTimer] retrying $_tries of $_maxRetries');
          await _callback();
        } else {
          _log.info('[async-client][RetyTimer] notifying limit reached.');
          reset();
          await _limitReachedCallback();
          _log.severe('[async-client][RetyTimer] max retries reached.');
        }
      } catch (e) {
        _log.severe('[async-client][RetyTimer] captured error calling delayed function: $e');
      }
    });
    _tries = _tries + 1;
  }

  int _delay() {
    return Utils.expBackoff(_initialWait, _maxWait, _tries, _jitterFn);
  }
}
