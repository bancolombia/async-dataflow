import 'package:channel_sender_client/src/utils/utils.dart';
import 'package:test/test.dart';

void main() {
  group('Utils tests.', () {
    test('Should generate random jitter', () {
      for (var i = 0; i < 100; i++) {
        var result = jitter(1000, 0.25);
        expect(result > 749, equals(true));
        expect(result < 1000, equals(true));
      }
    });

    test('Should generate exp backoff when current value is big', () {
      var result = expBackoff(50, 10000, 100);
      expect(result == 10000, equals(true));
    });

    test('Should generate Exp Backoff no Jitter', () {
      const expected = [
        [0, 10],
        [1, 20],
        [2, 40],
        [3, 80],
        [4, 160],
        [5, 320],
        [6, 640],
        [7, 1280],
        [8, 2560],
        [9, 5120],
        [10, 6000],
        [11, 6000],
      ];

      for (final e in expected) {
        var result = expBackoff(10, 6000, e.first);
        expect(result == e[1], equals(true));
      }
    });

    test('Should generate Exp Backoff with Jitter', () {
      const expected = [
        [0, 10],
        [1, 20],
        [2, 40],
        [3, 80],
        [4, 160],
        [5, 320],
        [6, 640],
        [7, 1280],
        [8, 2560],
        [9, 5120],
        [10, 6000],
        [11, 6000],
      ];

      var jitterFactor = 0.25;
      int jitterFn(int num) => jitter(num, jitterFactor);

      for (final e in expected) {
        var result = expBackoff(10, 6000, e.first, jitterFn);
        expect(result > (e[1] * (1 - jitterFactor)) - 1, equals(true));
        expect(result < e[1], equals(true));
      }
    });
  });
}
