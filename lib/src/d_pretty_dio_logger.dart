import 'dart:convert';
import 'package:custom_debug_console/debug_console_overlay.dart';
import 'package:dio/dio.dart';

class DPrettyDioLogger extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    dynamic body;

    if (options.data is FormData) {
      body = "Multipart FormData (skipped)";
    } else {
      body = options.data;
    }

    final log = {
      "method": options.method,
      "url": options.uri.toString(),
      "headers": options.headers,
      "query": options.queryParameters,
      "body": body,
    };

    DebugConsoleOverlay.logRequest(
      "- [${options.method}]: ${options.uri.path}\n${prettyJson(log)}",
    );

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    DebugConsoleOverlay.logResponse(
      "${response.requestOptions.uri.path}\n${prettyJson({
            "status": response.statusCode,
            "data": response.data,
          })}",
    );

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    DebugConsoleOverlay.logError(
      "${err.requestOptions.uri.path}\n${prettyJson({
            "status": err.response?.statusCode,
            "message": err.message,
            "data": err.response?.data,
          })}",
    );

    handler.next(err);
  }

  String prettyJson(dynamic json) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }
}
