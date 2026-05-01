// lib/core/app_config.dart
//
// Centralised runtime configuration.  Reads Supabase credentials from
// .env.local via flutter_dotenv — no secrets are compiled into the binary.
//
// Call [AppConfig.validate()] from main() after dotenv.load() to fail fast
// with a clear message if any required key is missing.

import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  /// Supabase project URL (from .env.local SUPABASE_URL).
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? _missing('SUPABASE_URL');

  /// Supabase anonymous (publishable) key (from .env.local SUPABASE_ANON_KEY).
  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? _missing('SUPABASE_ANON_KEY');

  /// Call after [dotenv.load()] to throw immediately if keys are absent.
  static void validate() {
    final missing = <String>[];
    if ((dotenv.env['SUPABASE_URL'] ?? '').isEmpty) {
      missing.add('SUPABASE_URL');
    }
    if ((dotenv.env['SUPABASE_ANON_KEY'] ?? '').isEmpty) {
      missing.add('SUPABASE_ANON_KEY');
    }
    if (missing.isNotEmpty) {
      throw StateError(
        'Missing required environment variables in .env.local: '
        '${missing.join(', ')}.\n'
        'Copy .env.example to .env.local and fill in your Supabase credentials.',
      );
    }
  }

  /// Single source of truth for the Android notification channel used by
  /// both [FlutterLocalNotificationsPlugin] and FCM payloads.
  static const String notificationChannelId = 'mediflow_alerts';
  static const String notificationChannelName = 'MediFlow Alerts';
  static const String notificationChannelDescription =
      'Patient updates, visit assignments, and follow-up tasks.';

  static Never _missing(String key) {
    throw StateError(
      '$key not found in .env.local. '
      'Copy .env.example to .env.local and fill in your Supabase credentials.',
    );
  }
}
