// lib/core/fcm_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:mediflow/core/app_config.dart';
import 'package:mediflow/core/navigation_service.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  debugPrint(
      '[FCM Background] ${message.notification?.title}: ${message.notification?.body}');
  // Local notification is shown automatically by FCM on Android.
  // iOS requires explicit call for background data-only messages.
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();

  static const _edgeFnPath = '/functions/v1/send-fcm-notification';

  // Role → Supabase table mapping.
  // All current roles live in the `doctors` table (auth_provider inserts
  // all users there). Update this map if assistants ever move to a separate
  // table (e.g., 'assistant': 'staff').
  static const Map<String, String> _roleToTable = {
    'head_doctor': 'doctors',
    'doctor': 'doctors',
    'assistant': 'doctors',
  };

  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;
  bool _quietHoursEnabled = false;
  int _quietStartHour = 22;
  int _quietEndHour = 7;
  DateTime? _lastTokenSync;
  UserRole? _userRole;

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    const channel = AndroidNotificationChannel(
      AppConfig.notificationChannelId,
      AppConfig.notificationChannelName,
      description: AppConfig.notificationChannelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localPlugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

    _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    _openedAppSub?.cancel();
    _openedAppSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    _initialized = true;
  }

  // ── Role context ──────────────────────────────────────────────────────────

  /// Called by [AuthNotifier] immediately after sign-in so token storage
  /// targets the correct table for this user's role.
  void setUserRole(UserRole role) {
    _userRole = role;
  }

  String get _tokenTable =>
      _roleToTable[_userRole?.databaseValue] ?? 'doctors';

  // ── Token management ──────────────────────────────────────────────────────

  /// Fetches the current FCM token and stores it in the role-appropriate table.
  Future<void> syncToken() async {
    try {
      if (_lastTokenSync != null &&
          DateTime.now().difference(_lastTokenSync!) <
              const Duration(hours: 12)) {
        return;
      }

      final token = await _fcm.getToken();
      if (token == null) return;
      debugPrint(
          '[FCM] Token: ${token.length > 20 ? "${token.substring(0, 20)}..." : token}');
      await _saveTokenToSupabase(token);
      _lastTokenSync = DateTime.now();

      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _fcm.onTokenRefresh.listen(_saveTokenToSupabase);
    } catch (e) {
      debugPrint('[FCM] syncToken error: $e');
    }
  }

  Future<void> _saveTokenToSupabase(String token) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      final table = _tokenTable;
      await client.retry(() => client.from(table).update({
        'fcm_token': token,
        'fcm_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId));

      debugPrint('[FCM] Token saved to `$table`');
    } catch (e) {
      debugPrint('[FCM] _saveTokenToSupabase error: $e');
    }
  }

  /// Clears the FCM token on logout so stale tokens don't receive notifications.
  Future<void> clearToken() async {
    try {
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId != null) {
        final table = _tokenTable;
        await client.retry(() => client.from(table).update({
          'fcm_token': null,
        }).eq('id', userId));
      }

      await _fcm.deleteToken();
      _lastTokenSync = null;
      _userRole = null;
    } catch (e) {
      debugPrint('[FCM] clearToken error: $e');
    }
  }

  /// Tear down all FCM subscriptions. Safe to call from `dispose`-style flows.
  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _openedAppSub?.cancel();
    await _tokenRefreshSub?.cancel();
    _foregroundSub = null;
    _openedAppSub = null;
    _tokenRefreshSub = null;
    _initialized = false;
  }

  void configureQuietHours({
    required bool enabled,
    int startHour = 22,
    int endHour = 7,
  }) {
    _quietHoursEnabled = enabled;
    _quietStartHour = startHour.clamp(0, 23);
    _quietEndHour = endHour.clamp(0, 23);
  }

  // ── Send notifications (app-side) ─────────────────────────────────────────

  /// Sends a push notification to a recipient by looking up their FCM token.
  /// Queries the `doctors` table (which holds all current roles).
  /// Update the query to a unified view or `user_fcm_tokens` table if the
  /// schema is ever split by role.
  static Future<bool> sendToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final client = Supabase.instance.client;
      final result = await client.retry(() => client
          .from('doctors')
          .select('fcm_token')
          .eq('id', userId)
          .maybeSingle());

      final token = result?['fcm_token'] as String?;
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] User $userId has no FCM token, skipping push');
        return false;
      }

      return _callEdgeFunction(
        token: token,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      debugPrint('[FCM] sendToUser error: $e');
      return false;
    }
  }

  /// Legacy alias — prefer [sendToUser].
  static Future<bool> sendToDoctor({
    required String doctorId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) =>
      sendToUser(userId: doctorId, title: title, body: body, data: data);

  /// Sends a push notification directly to a known FCM token.
  static Future<bool> sendToToken({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      return _callEdgeFunction(
        token: token,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      debugPrint('[FCM] sendToToken error: $e');
      return false;
    }
  }

  static Future<bool> _callEdgeFunction({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final accessToken = await _getValidAccessToken();
    if (accessToken == null) {
      debugPrint('[FCM] Cannot call edge function: no valid auth session.');
      return false;
    }

    try {
      final res = await http.post(
        Uri.parse('${AppConfig.supabaseUrl}$_edgeFnPath'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': token,
          'title': title,
          'body': body,
          if (data != null) 'data': data,
        }),
      );

      if (res.statusCode == 200) {
        debugPrint('[FCM] Push sent successfully');
        return true;
      }
      debugPrint('[FCM] Edge function error ${res.statusCode}: ${res.body}');
      if (res.statusCode == 401 || res.statusCode == 403) {
        debugPrint('[FCM] Auth rejected by edge function, user must re-authenticate.');
      }
      return false;
    } catch (e) {
      debugPrint('[FCM] Edge function network/call error: $e');
      return false;
    }
  }

  static Future<String?> _getValidAccessToken() async {
    final auth = Supabase.instance.client.auth;
    var session = auth.currentSession;
    if (session == null) return null;

    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiry = session.expiresAt ?? 0;
    final isExpired = expiry <= nowSeconds + 30;
    if (!isExpired) return session.accessToken;

    try {
      final refreshed = await auth.refreshSession();
      session = refreshed.session ?? auth.currentSession;
      return session?.accessToken;
    } catch (e) {
      // Network hiccup or stale token — return null so the push is skipped.
      // Do NOT sign the user out here; this is a background notification task
      // and forcing a sign-out would disrupt the user's active session.
      debugPrint('[FCM] Session refresh failed before edge call: $e');
      return null;
    }
  }

  // ── Foreground / tap handlers ─────────────────────────────────────────────

  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM Foreground] ${message.notification?.title}');
    final notification = message.notification;
    if (notification == null) return;
    if (_isQuietHoursNow()) {
      debugPrint(
          '[FCM Foreground] Quiet hours active, suppressing local notification.');
      return;
    }

    final category = message.data['category']?.toString() ??
        _categoryForType(message.data['type']?.toString());

    _localPlugin.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConfig.notificationChannelId,
          AppConfig.notificationChannelName,
          importance: Importance.max,
          priority: Priority.high,
          groupKey: 'mediflow.$category',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint('[FCM Tap] ${message.data}');
    final type = message.data['type']?.toString();
    final patientId = message.data['patientId']?.toString() ??
        message.data['patient_id']?.toString();
    if ((type == 'stale_patient' || type == 'patient_update') &&
        patientId != null) {
      openPatientDetailFromNotification(patientId);
    }
  }

  bool _isQuietHoursNow() {
    if (!_quietHoursEnabled) return false;
    final hour = DateTime.now().hour;
    if (_quietStartHour == _quietEndHour) return true;
    if (_quietStartHour < _quietEndHour) {
      return hour >= _quietStartHour && hour < _quietEndHour;
    }
    return hour >= _quietStartHour || hour < _quietEndHour;
  }

  String _categoryForType(String? type) {
    if (type == null) return 'system';
    if (type.contains('followup')) return 'followup';
    if (type.contains('visit')) return 'visit';
    if (type.contains('patient') || type.contains('status')) return 'patient';
    return 'system';
  }
}
