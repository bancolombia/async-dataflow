import 'dart:math';

/// A utility library for handling jitter and exponential backoff strategies.
///
/// Provides functions to calculate jitter based on a base time and a random factor,
/// as well as to compute the wait time for exponential backoff retries.
///
/// Functions:
/// - [jitter]: Calculates a jitter value based on the provided base time and random factor.
/// - [expBackoff]: Computes the wait time for exponential backoff based on initial wait time,
///   maximum wait time, and the number of actual retries, with an optional jitter function.
/// - [checkString]: Trims the input string and returns an empty string if the trimmed result is empty.
///
/// Example:
/// ```dart
/// int waitTime = expBackoff(100, 10000, 3);
/// String? validatedString = checkString("   Hello World!   ");
/// ```

int _defaultJitterFn(int num) => num;

int jitter(int baseTime, double randomFactor) {
  var rest = baseTime * randomFactor;
  var rng = Random();
  var jitter = (baseTime - rest) + rng.nextDouble() * rest;

  return jitter.toInt();
}

int expBackoff(
  int initial,
  int max,
  int actualRetry, [
  Function? jitterFn,
]) {
  Function curatedFn;
  curatedFn = jitterFn ?? _defaultJitterFn;
  var base = initial << actualRetry;
  var willWait = 0;
  var isOverflowing = base <= 0;
  willWait = (base > max || isOverflowing) ? curatedFn(max) : curatedFn(base);

  return willWait.toInt();
}

String? checkString(String data) {
  var trim = data.trim();

  return trim.isEmpty ? '' : trim;
}
