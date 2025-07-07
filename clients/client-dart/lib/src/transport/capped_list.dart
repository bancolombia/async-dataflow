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