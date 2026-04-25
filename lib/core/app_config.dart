// lib/core/app_config.dart
//
// Centralised, build-time configuration. Keeps Supabase URL / anon key in
// one place so `main.dart`, `fcm_service.dart`, and any other call site
// stay in sync. Override at build time with --dart-define.

class AppConfig {
  AppConfig._();

  /// Supabase project URL. Override with --dart-define=SUPABASE_URL=...
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://dtmkzvptamydlgubmzlb.supabase.co',
  );

  /// Supabase anon (publishable) key. Override with
  /// --dart-define=SUPABASE_ANON_KEY=...
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_30AYi1oyhTvuzqtcN-BsbQ_j4MnFKHv',
  );

  /// Single source of truth for the Android notification channel used by
  /// both [FlutterLocalNotificationsPlugin] and FCM payloads.
  static const String notificationChannelId = 'mediflow_alerts';
  static const String notificationChannelName = 'MediFlow Alerts';
  static const String notificationChannelDescription =
      'Patient updates, visit assignments, and follow-up tasks.';
}
