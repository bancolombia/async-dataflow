import 'dart:math';

class Utils {
  static int _defaultJitterFn(int num) => num;

  static int jitter(int baseTime, double randomFactor) {
    var rest = baseTime * randomFactor;
    var rng = Random();
    var jitter = (baseTime - rest) + rng.nextDouble() * rest;

    return jitter.toInt();
  }

  static int expBackoff(int initial, int max, int actualRetry,
      [Function? jitterFn]) {
    Function curatedFn;
    if (jitterFn == null) {
      curatedFn = _defaultJitterFn;
    } else {
      curatedFn = jitterFn;
    }
    var base = initial * pow(2, actualRetry);
    var willWait = 0;
    if (base > max) {
      willWait = curatedFn(max);
    } else {
      willWait = curatedFn(base);
    }
    return willWait.toInt();
  }

  static String? checkString(String data) {
    var trim = data.trim();

    return trim.isEmpty ? '' : trim;
  }
}
