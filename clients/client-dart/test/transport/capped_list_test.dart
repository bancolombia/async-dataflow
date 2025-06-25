import 'package:channel_sender_client/src/utils/capped_list.dart';
import 'package:test/test.dart';

void main() {
  group('CappedList', () {
    test('should add elements to the list', () {
      final cappedList = CappedList<int>(3);

      cappedList.add(1);
      cappedList.add(2);

      expect(cappedList.contains(1), isTrue);
      expect(cappedList.contains(2), isTrue);
      expect(cappedList.contains(3), isFalse);
    });

    test('should not exceed max size', () {
      final cappedList = CappedList<int>(3);

      cappedList.add(1);
      cappedList.add(2);
      cappedList.add(3);
      cappedList.add(4); // This should remove the oldest element (1)

      expect(cappedList.contains(1), isFalse);
      expect(cappedList.contains(2), isTrue);
      expect(cappedList.contains(3), isTrue);
      expect(cappedList.contains(4), isTrue);
    });

    test('should clear all elements', () {
      final cappedList = CappedList<int>(3);

      cappedList.add(1);
      cappedList.add(2);
      cappedList.clear();

      expect(cappedList.contains(1), isFalse);
      expect(cappedList.contains(2), isFalse);
    });

    test('should handle adding elements when maxSize is 1', () {
      final cappedList = CappedList<int>(1);

      cappedList.add(1);
      cappedList.add(2); // This should replace 1

      expect(cappedList.contains(1), isFalse);
      expect(cappedList.contains(2), isTrue);
    });

    test('should handle an empty list correctly', () {
      final cappedList = CappedList<int>(3);

      expect(cappedList.contains(1), isFalse);
    });
  });
}
