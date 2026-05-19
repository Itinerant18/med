import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/fcm_service.dart';
import 'package:mediflow/core/supabase_client.dart';

/// Thin wrapper around the `send-push-notification` Supabase Edge Function.
///
/// Also inserts rows into the `notifications` table for each recipient so
/// in-app notifications appear via the Realtime subscription even if the
/// FCM push fails.
///
/// All methods are best-effort — failures are logged and silently ignored so
/// they never interrupt the calling workflow.
class PushNotificationService {
  PushNotificationService._();

  /// Sends a push notification to one or more recipients via the
  /// `send-push-notification` Edge Function, and inserts in-app notification
  /// rows into the `notifications` table for each recipient.
  static Future<void> sendNotification({
    required Ref ref,
    required String event,
    required List<String> recipientIds,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    if (recipientIds.isEmpty) return;

    final supabase = ref.read(supabaseClientProvider);
    final pushData = <String, String>{
      'event': event,
      if (data != null) ...data,
    };

    // ── FCM push (best-effort) ──
    try {
      await supabase.functions.invoke('send-push-notification', body: {
        'event': event,
        'recipientIds': recipientIds,
        'title': title,
        'body': body,
        if (data != null) 'data': data,
      });
    } catch (e) {
      debugPrint('PushNotificationService: push invoke non-fatal error — $e');
      // The new edge function may not be deployed yet in some environments.
      // Fall back to the already deployed per-token FCM path so notifications
      // still reach devices while preserving the in-app notification insert.
      for (final recipientId in recipientIds) {
        try {
          await FcmService.sendToDoctor(
            doctorId: recipientId,
            title: title,
            body: body,
            data: pushData,
          );
        } catch (fallbackError) {
          debugPrint(
            'PushNotificationService: FCM fallback non-fatal error — $fallbackError',
          );
        }
      }
    }

    // ── In-app notifications (independent of push) ──
    try {
      for (final recipientId in recipientIds) {
        await supabase.from('notifications').insert({
          'recipient_id': recipientId,
          'category': _categoryFromEvent(event),
          'title': title,
          'body': body,
          'entity_type': data?['entityType'],
          'entity_id': data?['entityId'],
          'priority': data?['priority'] ?? 'normal',
        });
      }
    } catch (e) {
      debugPrint(
          'PushNotificationService: in-app insert non-fatal error — $e');
    }
  }

  static String _categoryFromEvent(String event) => switch (event) {
        'followup_assigned' ||
        'followup_completed' ||
        'followup_reviewed' =>
          'followup',
        'outside_visit_recorded' => 'visit',
        'patient_status_changed' => 'patient',
        _ => 'system',
      };
}
