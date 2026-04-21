// lib/core/fcm_service.dart
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:mediflow/core/navigation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  debugPrint('[FCM Background] ${message.notification?.title}: ${message.notification?.body}');
  // Local notification is shown automatically by FCM on Android.
  // iOS requires explicit call for background data-only messages.
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();

  static const _supabaseUrl = 'https://dtmkzvptamydlgubmzlb.supabase.co';
  static const _edgeFnPath = '/functions/v1/send-fcm-notification';

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    // 1. Request permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // 2. Android notification channel
    const channel = AndroidNotificationChannel(
      'mediflow_alerts',
      'MediFlow Alerts',
      description: 'Patient updates, visit assignments, and follow-up tasks.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 3. Local notifications plugin init
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localPlugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // 4. Foreground display options
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 5. Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

    // 6. Handle foreground messages
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // 7. Handle notification tap when app was in background
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
  }

  // ── Token management ──────────────────────────────────────────────────────

  /// Gets the current FCM token and stores it in the doctors table.
  Future<void> syncToken() async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;
      debugPrint('[FCM] Token: ${token.substring(0, 20)}...');
      await _saveTokenToSupabase(token);

      // Listen for token refreshes
      _fcm.onTokenRefresh.listen(_saveTokenToSupabase);
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
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client.from('doctors').update({
        'fcm_token': null,
      }).eq('id', userId);

      await _fcm.deleteToken();
    } catch (e) {
      debugPrint('[FCM] clearToken error: $e');
    }
  }

  // ── Send notifications (app-side) ─────────────────────────────────────────

  /// Sends a push notification to a specific doctor via the Supabase Edge Function.
  /// Requires the target doctor's FCM token from the doctors table.
  static Future<void> sendToDoctor({
    required String doctorId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // Fetch the target doctor's FCM token
      final result = await Supabase.instance.client
          .from('doctors')
          .select('fcm_token')
          .eq('id', doctorId)
          .maybeSingle();

      final token = result?['fcm_token'] as String?;
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] Doctor $doctorId has no FCM token, skipping push');
        return;
      }

      await _callEdgeFunction(token: token, title: title, body: body, data: data);
    } catch (e) {
      debugPrint('[FCM] sendToDoctor error: $e');
    }
  }

  /// Sends a push notification directly to a known FCM token.
  static Future<void> sendToToken({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      await _callEdgeFunction(token: token, title: title, body: body, data: data);
    } catch (e) {
      debugPrint('[FCM] sendToToken error: $e');
    }
  }

  static Future<void> _callEdgeFunction({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    final res = await http.post(
      Uri.parse('$_supabaseUrl$_edgeFnPath'),
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

    if (res.statusCode != 200) {
      debugPrint('[FCM] Edge function error ${res.statusCode}: ${res.body}');
    } else {
      debugPrint('[FCM] Push sent successfully');
    }
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
          'mediflow_alerts',
          'MediFlow Alerts',
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
