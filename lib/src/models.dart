import 'package:flutter/material.dart';

enum LogLevel { debug, request, response, error }

extension LogLevelX on LogLevel {
  String get label {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.request:
        return 'REQUEST';
      case LogLevel.response:
        return 'RESPONSE';
    }
  }
}

@immutable
class LogEvent {
  final DateTime ts;
  final LogLevel level;
  final String message;
  final String? tag;

  const LogEvent(this.ts, this.level, this.message, [this.tag]);
}

/// Represents a grouped network request with all related logs
@immutable
class NetworkRequestGroup {
  final String key; // method + url combination
  final String method;
  final String url;
  final List<LogEvent> events;
  final DateTime firstRequestTime;
  final DateTime? lastResponseTime;
  final int? statusCode;
  final bool hasError;

  const NetworkRequestGroup({
    required this.key,
    required this.method,
    required this.url,
    required this.events,
    required this.firstRequestTime,
    this.lastResponseTime,
    this.statusCode,
    this.hasError = false,
  });

  /// Get the display status of this request group
  String get statusDisplay {
    if (hasError) {
      if (statusCode != null) return 'ERROR $statusCode';
      return 'ERROR';
    }
    if (statusCode != null) {
      if (statusCode! >= 200 && statusCode! < 300) return 'SUCCESS $statusCode';
      if (statusCode! >= 400) return 'FAILED $statusCode';
      return '$statusCode';
    }
    return 'PENDING';
  }

  /// Get the color for the status
  Color get statusColor {
    if (hasError) return Colors.red[600]!;
    if (statusCode == null) return Colors.amber[600]!; // pending
    if (statusCode! >= 200 && statusCode! < 300)
      return Colors.green[600]!; // success
    if (statusCode! >= 400) return Colors.red[600]!; // error
    if (statusCode! >= 300) return Colors.orange[600]!; // redirect
    return Colors.blue[600]!; // other
  }

  /// Get a readable status description
  String get statusDescription {
    if (hasError && statusCode == null) return 'Request failed with error';
    if (statusCode == null) return 'Request in progress...';

    if (statusCode! >= 200 && statusCode! < 300) {
      return 'Request completed successfully';
    } else if (statusCode! >= 400 && statusCode! < 500) {
      return 'Client error occurred';
    } else if (statusCode! >= 500) {
      return 'Server error occurred';
    } else if (statusCode! >= 300) {
      return 'Request redirected';
    }
    return 'Request completed';
  }

  /// Duration of the request if completed
  Duration? get duration {
    if (lastResponseTime == null) return null;
    return lastResponseTime!.difference(firstRequestTime);
  }
}
