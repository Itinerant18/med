// lib/core/fcm_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:mediflow/core/app_config.dart';
import 'package:mediflow/core/navigation_service.dart';
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

  // Tracked subscriptions so we can cancel and re-subscribe across logouts.
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;

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

    // Track these subscriptions so we can cancel them if the app shuts the
    // FCM session down (logout, reinstall) and resume them on next sign-in.
    _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    _openedAppSub?.cancel();
    _openedAppSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    _initialized = true;
  }

  // ── Token management ──────────────────────────────────────────────────────

  /// Gets the current FCM token and stores it in the doctors table.
  Future<void> syncToken() async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;
      debugPrint(
          '[FCM] Token: ${token.length > 20 ? "${token.substring(0, 20)}..." : token}');
      await _saveTokenToSupabase(token);

      // Replace any stale refresh subscription with a fresh one bound to the
      // current user, so token rotations always update the right doctor row.
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _fcm.onTokenRefresh.listen(_saveTokenToSupabase);
    } catch (e) {
      debugPrint('[FCM] syncToken error: $e');
    }
  }

  Future<void> _saveTokenToSupabase(String token) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client.from('doctors').update({
        'fcm_token': token,
        'fcm_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      debugPrint('[FCM] Token saved to Supabase');
    } catch (e) {
      debugPrint('[FCM] _saveTokenToSupabase error: $e');
    }
  }

  /// Clears the FCM token on logout so stale tokens don't receive notifications.
  Future<void> clearToken() async {
    try {
      // Stop watching for token rotations on the now-departing user. We'll
      // re-subscribe on the next syncToken() after they sign in again.
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client.from('doctors').update({
          'fcm_token': null,
        }).eq('id', userId);
      }

      await _fcm.deleteToken();
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

  // ── Send notifications (app-side) ─────────────────────────────────────────

  /// Sends a push notification to a specific doctor via the Supabase Edge Function.
  /// Requires the target doctor's FCM token from the doctors table.
  static Future<bool> sendToDoctor({
    required String doctorId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final result = await Supabase.instance.client
          .from('doctors')
          .select('fcm_token')
          .eq('id', doctorId)
          .maybeSingle();

      final token = result?['fcm_token'] as String?;
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] Doctor $doctorId has no FCM token, skipping push');
        return false;
      }

      return _callEdgeFunction(
        token: token,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      debugPrint('[FCM] sendToDoctor error: $e');
      return false;
    }
  }

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
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return false;

    final res = await http.post(
      Uri.parse('${AppConfig.supabaseUrl}$_edgeFnPath'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
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
    return false;
  }

  // ── Foreground / tap handlers ─────────────────────────────────────────────

  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM Foreground] ${message.notification?.title}');
    final notification = message.notification;
    if (notification == null) return;

    _localPlugin.show(
      message.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConfig.notificationChannelId,
          AppConfig.notificationChannelName,
          importance: Importance.max,
          priority: Priority.high,
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
        iOS: DarwinNotificationDetails(
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
    final patientId = message.data['patientId']?.toString();
    if (type == 'stale_patient' && patientId != null) {
      openPatientDetailFromNotification(patientId);
    }
  }
}
