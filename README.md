
# debug_console_overlay

A lightweight, draggable **debug console overlay** for Flutter. It shows logs in-app so you don't have to switch back to the IDE console. **Disabled in release builds.**

## Features (v0.1.0)
- Floating **bubble** that opens a bottom **panel**
- **Logs tab** with search and level/tag filters
- **Network tab** allows api request logging
- Capture **FlutterError** automatically
- Optional helper to capture `print()` output via a **Zone**
- **Ring buffer** (keeps last N logs) for performance
- 0-setup: just wrap your app in `DebugConsoleOverlay`

## Quick start

```dart
void main() {
  // Optional: capture print() into overlay as well.
  DebugConsoleOverlay.runWithPrintCapture(() {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DebugConsoleOverlay(
      enabled: kDebugMode, // auto no-op in release
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Debug Console Overlay')),
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                DebugConsoleOverlay.log('Button clicked', level: LogLevel.info, tag: 'UI');
              },
              child: const Text('Log something'),
            ),
          ),
        ),
      ),
    );
  }
}
```

## API

```dart
// Log text with level & optional tag
DebugConsoleOverlay.log('Payment started', level: LogLevel.info, tag: 'PAY');

// Wrap runApp to also capture print() output
DebugConsoleOverlay.runWithPrintCapture(() {
  runApp(const MyApp());
});
```

## Not included (yet)
- State tabs (planned next versions)
- Interceptors/adapters (Provider/GetX/Riverpod)

## Safety
- The overlay is **disabled in release** (guard with `kDebugMode`).
- Reduces memory footprint via a **ring buffer**; defaults to last 200 logs.

## Roadmap
- v0.2: Network tab + basic request/response logging helpers
- v0.3: State snapshots tab + redaction helpers
- v1.0: Export to JSON, unread badges, perf polish

## License
MIT