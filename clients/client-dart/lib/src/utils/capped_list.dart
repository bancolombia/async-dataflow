/// A class that represents a capped list, which maintains a fixed maximum size.
/// When the maximum size is reached, adding a new element will remove the oldest element.
///
/// This class is generic and can hold elements of any type [T].
///
/// Example usage:
/// ```dart
/// final cappedList = CappedList<int>(3);
/// cappedList.add(1);
/// cappedList.add(2);
/// cappedList.add(3);
/// cappedList.add(4); // This will remove the element '1'
/// print(cappedList.contains(1)); // false
/// cappedList.clear(); // Clears the list
/// ```
///
/// Properties:
/// - [maxSize]: The maximum number of elements the list can hold.
/// - [_list]: The internal list that stores the elements.
class CappedList<T> {
  final int maxSize;
  final List<T> _list = [];

  CappedList(this.maxSize);

  void add(T element) {
    if (_list.length >= maxSize) {
      _list.removeAt(0); // Remove the oldest element
    }
    _list.add(element);
  }

  bool contains(T element) {
    return _list.contains(element);
  }

  void clear() {
    _list.clear();
  }
}
