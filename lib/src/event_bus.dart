
import 'dart:async';
import 'models.dart';
import 'utils/ring_buffer.dart';

class DebugBus {
  DebugBus._();
  static final DebugBus instance = DebugBus._();

  final RingBuffer<LogEvent> _logs = RingBuffer<LogEvent>(capacity: 200);
  final StreamController<LogEvent> _logsCtrl = StreamController<LogEvent>.broadcast();

  void addLog(LogEvent e) {
    _logs.add(e);
    _logsCtrl.add(e);
  }

  List<LogEvent> get logsSnapshot => _logs.toList();
  Stream<LogEvent> get logsStream => _logsCtrl.stream;

  void dispose() {
    _logsCtrl.close();
  }
}
