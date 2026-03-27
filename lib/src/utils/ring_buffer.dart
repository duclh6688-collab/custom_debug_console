class RingBuffer<T> {
  final int capacity;
  final List<T?> _buffer;
  int _start = 0;
  int _length = 0;

  RingBuffer({required this.capacity}) : _buffer = List.filled(capacity, null);

  void add(T value) {
    final index = (_start + _length) % capacity;
    _buffer[index] = value;
    if (_length < capacity) {
      _length++;
    } else {
      _start = (_start + 1) % capacity;
    }
  }

  List<T> toList() {
    return List.generate(_length, (i) => _buffer[(_start + i) % capacity] as T);
  }

  // 🔥 CLEAR method
  void clear() {
    _start = 0;
    _length = 0;
    for (int i = 0; i < capacity; i++) {
      _buffer[i] = null;
    }
  }

  // Optional: removeWhere
  void removeWhere(bool Function(T) test) {
    final temp = toList()..removeWhere(test);
    clear();
    for (final e in temp) {
      add(e);
    }
  }
}
