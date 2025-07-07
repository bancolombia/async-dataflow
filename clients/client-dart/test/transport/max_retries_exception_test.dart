import 'package:channel_sender_client/src/exceptions/max_retries_exception.dart';
import 'package:test/test.dart';

void main() {
  test('should create exception with message', () {
    final exception = MaxRetriesException('Retry limit exceeded');

    expect(exception.message, 'Retry limit exceeded');
  });

  test('should throw MaxRetriesException', () {
    void throwException() {
      throw MaxRetriesException('Too many attempts');
    }

    expect(throwException, throwsA(isA<MaxRetriesException>()));
  });

  test('should have correct toString output', () {
    final exception = MaxRetriesException('Failed after 3 retries');

    expect(exception.toString(), 'MaxRetriesException: Failed after 3 retries');
  });
}
