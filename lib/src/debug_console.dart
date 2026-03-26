import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'event_bus.dart';
import 'models.dart';
import 'ui/bubble.dart';
import 'ui/panel.dart';

enum DebugTab { logs, network }

class DebugConsoleOverlay extends StatefulWidget {
  const DebugConsoleOverlay({
    super.key,
    required this.child,
    this.enabled = kDebugMode,
    this.showBubble = true,
    this.initialTab = DebugTab.logs,
    this.panelHeightFraction = 0.6,
    this.showNetworkTab = true,
  });

  final Widget child;
  final bool enabled;
  final bool showBubble;
  final DebugTab initialTab;
  final double panelHeightFraction;
  final bool showNetworkTab;

  static void logDebug(String msg,
      {LogLevel level = LogLevel.debug, String? tag}) {
    DebugBus.instance
        .addLog(LogEvent(DateTime.now(), level, '[DEBUG] $msg', tag));
  }

  static void logError(String msg,
      {LogLevel level = LogLevel.error, String? tag}) {
    DebugBus.instance
        .addLog(LogEvent(DateTime.now(), level, '[ERROR] $msg', tag));
  }

  static void logRequest(String msg,
      {LogLevel level = LogLevel.request, String? tag}) {
    DebugBus.instance
        .addLog(LogEvent(DateTime.now(), level, '[REQUEST] $msg', tag));
  }

  static void logResponse(String msg,
      {LogLevel level = LogLevel.response, String? tag}) {
    DebugBus.instance
        .addLog(LogEvent(DateTime.now(), level, '[RESPONSE] $msg', tag));
  }

  static void logBloc(String msg,
      {LogLevel level = LogLevel.debug, String? tag}) {
    DebugBus.instance
        .addLog(LogEvent(DateTime.now(), level, '[BLOC] $msg', tag));
  }

  static void stream(String msg,
      {LogLevel level = LogLevel.debug, String? tag}) {
    DebugBus.instance
        .addLog(LogEvent(DateTime.now(), level, '[STREAM] $msg', tag));
  }

  static void log(String msg, {LogLevel level = LogLevel.debug, String? tag}) {
    DebugBus.instance.addLog(LogEvent(DateTime.now(), level, msg, tag));
  }

  /// Optional helper to capture print() while running your app.
  static T runWithPrintCapture<T>(T Function() body) {
    return runZoned<T>(
      body,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          if (_shouldLog(line)) {
            DebugBus.instance.addLog(
              LogEvent(DateTime.now(), LogLevel.debug, line),
            );
          }
          parent.print(zone, line);
        },
      ),
    );
  }

  static bool _shouldLog(String line) {
    return line.startsWith('[STREAM]') ||
        line.startsWith('[REQUEST]') ||
        line.startsWith('[RESPONSE]') ||
        line.startsWith('[ERROR]') ||
        line.startsWith('[DEBUG]') ||
        line.startsWith('[BLOC]');
  }

  @override
  State<DebugConsoleOverlay> createState() => _DebugConsoleOverlayState();
}

class _DebugConsoleOverlayState extends State<DebugConsoleOverlay> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      // Capture framework errors
      final prev = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        DebugConsoleOverlay.log(details.exceptionAsString(),
            level: LogLevel.error, tag: 'FlutterError');
        prev?.call(details);
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Stack(
      alignment: Alignment.topLeft, // Explicit alignment instead of directional
      children: [
        widget.child,
        if (widget.showBubble)
          DebugBubble(
            onTap: () => setState(() => _open = true),
          ),
        if (_open)
          _BottomSheetPanel(
            onClose: () => setState(() => _open = false),
            heightFraction: widget.panelHeightFraction,
            showNetworkTab: widget.showNetworkTab,
          ),
      ],
    );
  }
}

class _BottomSheetPanel extends StatelessWidget {
  const _BottomSheetPanel({
    required this.onClose,
    required this.heightFraction,
    required this.showNetworkTab,
  });

  final VoidCallback onClose;
  final double heightFraction;
  final bool showNetworkTab;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final h = media.size.height * heightFraction;
    return Positioned.fill(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: h,
          width: media.size.width,
          child: DebugPanel(
            onClose: onClose,
            showNetworkTab: showNetworkTab,
          ),
        ),
      ),
    );
  }
}
