
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
      enabled: flavor != prod, // auto no-op in release
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
dio.interceptors.add(DPrettyDioLogger());

// Wrap runApp to also capture print() output
DebugConsoleOverlay.runWithPrintCapture(() {
  runApp(const MyApp());
});
```

## License
MIT