
class RingBuffer<T> {
  RingBuffer({this.capacity = 200}) : assert(capacity > 0);

  final int capacity;
  final List<T> _items = <T>[];

  void add(T value) {
    if (_items.length >= capacity) {
      // remove oldest (index 0) — simple for small capacities
      _items.removeAt(0);
    }
    _items.add(value);
  }

  List<T> toList() => List<T>.unmodifiable(_items);
  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;
  void clear() => _items.clear();
}
