import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Configure and expose the shared Supabase client for app-wide data access.

/// Provider for the global Supabase client instance.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Extension to add retry logic and standardized error handling to Supabase calls.
extension SupabaseRetry on SupabaseClient {
  /// Retries a Supabase operation if it fails due to transient network errors.
  Future<T> retry<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        return await operation();
      } catch (e) {
        if (attempts >= maxAttempts || !_isTransientError(e)) {
          rethrow;
        }
        await Future.delayed(delay * attempts);
      }
    }
  }

  bool _isTransientError(dynamic e) {
    if (e is SocketException || e is TimeoutException) {
      return true;
    }
    if (e is PostgrestException) {
      // 502 Bad Gateway, 503 Service Unavailable, 504 Gateway Timeout
      final code = e.code;
      return code == '502' || code == '503' || code == '504';
    }
    final msg = e.toString().toLowerCase();
    return msg.contains('network') ||
        msg.contains('connection refused') ||
        msg.contains('connection timed out');
  }
}
