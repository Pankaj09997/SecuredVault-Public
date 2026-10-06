import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// An interceptor that implements client-side throttling to prevent
/// the app from spamming the server and handles 429 Too Many Requests.
class ThrottlingInterceptor extends Interceptor {
  final int minIntervalMs;
  final Map<String, int> _lastRequestTimes = {};

  ThrottlingInterceptor({this.minIntervalMs = 500});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final path = options.path;

    // Check if this endpoint was requested too recently
    if (_lastRequestTimes.containsKey(path)) {
      final lastTime = _lastRequestTimes[path]!;
      final interval = now - lastTime;
      
      if (interval < minIntervalMs) {
        print("Throttling request to $path (rejected: ${interval}ms < ${minIntervalMs}ms)");
        
        // Reject the request with a specific error
        return handler.reject(
          DioException(
            requestOptions: options,
            error: "Request throttled. Please wait.",
            type: DioExceptionType.cancel,
          ),
        );
      }
    }

    _lastRequestTimes[path] = now;
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 429) {
      // Handle Rate Limiting globally
      print("Global Rate Limit Triggered (429)");
      // You could trigger a global notification or event here
    }
    super.onError(err, handler);
  }
}
