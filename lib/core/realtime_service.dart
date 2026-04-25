// lib/core/realtime_service.dart
//
// Subscribes to Supabase Realtime DB changes and fires:
//  • Local push (flutter_local_notifications) for the current user
//  • Remote FCM push (via Edge Function) to the assigned/affected doctor
//
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediflow/core/fcm_service.dart';
import 'package:mediflow/core/notification_service.dart';
import 'package:mediflow/core/notification_provider.dart';
import 'package:mediflow/models/app_notification.dart';

class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  RealtimeChannel? _channel;
  String? _currentDoctorName;
  bool _isSubscribed = false;
  // Use the root ProviderContainer so we never hold onto a widget-bound Ref.
  // ProviderContainer lives for the app's lifetime — safe to retain.
  ProviderContainer? _container;

  void subscribeToPatientChanges(
    String currentDoctorName,
    ProviderContainer container,
  ) {
    if (_isSubscribed && _currentDoctorName == currentDoctorName) {
      _container = container;
      return;
    }

    _container = container;
    _currentDoctorName = currentDoctorName;
    _channel?.unsubscribe();
    _isSubscribed = false;

    try {
      _channel = Supabase.instance.client
          .channel('mediflow:patients:${Supabase.instance.client.auth.currentUser?.id ?? "anon"}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'patients',
            callback: (payload) =>
                _handlePatientUpdate(payload, currentDoctorName),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'patients',
            callback: (payload) =>
                _handlePatientInsert(payload, currentDoctorName),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'visits',
            callback: (payload) =>
                _handleVisitUpdate(payload, currentDoctorName),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'dr_visits',
            callback: (payload) => _handleDrVisitInsert(payload),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'followup_tasks',
            callback: (payload) => _handleFollowupTaskInsert(payload),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'followup_tasks',
            callback: (payload) => _handleFollowupUpdate(payload),
          )
          .subscribe((status, error) {
        if (error != null) {
          debugPrint('RealtimeService error: $error');
          _isSubscribed = false;
        } else {
          _isSubscribed = status == RealtimeSubscribeStatus.subscribed;
        }
      });
    } catch (e) {
      debugPrint('RealtimeService subscribe failed: $e');
    }
  }

  // ── dr_visits insert → notify assigned agent ──────────────────────────────

  void _handleDrVisitInsert(PostgresChangePayload payload) {
    try {
      final row = payload.newRecord;
      final assignedAgentId = row['assigned_agent_id']?.toString();
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      if (assignedAgentId != null && assignedAgentId == currentUserId) {
        // In-app notification
        _addInAppNotification(
          id: 'visit-${row['id']}',
          title: 'New Visit Assigned',
          body: 'You have been assigned a new patient visit.',
          type: 'visit_assignment',
        );

        // Local push
        NotificationService.instance.showVisitAssignedNotification(
          patientName: 'a patient',
          doctorName: 'your lead',
        );
      } else if (assignedAgentId != null) {
        // Send FCM push to the assigned agent
        FcmService.sendToDoctor(
          doctorId: assignedAgentId,
          title: 'New Visit Assigned',
          body: 'A new patient visit has been assigned to you.',
          data: {'type': 'visit_assignment', 'visit_id': row['id']?.toString() ?? ''},
        );
      }
    } catch (e) {
      debugPrint('Error handling dr_visit insert: $e');
    }
  }

  // ── followup_tasks insert → notify assigned agent ─────────────────────────

  void _handleFollowupTaskInsert(PostgresChangePayload payload) {
    final row = payload.newRecord;
    final assignedTo = row['assigned_to']?.toString();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final patientId = row['patient_id']?.toString();
    final dueDate = row['due_date']?.toString() ?? 'soon';
    final taskId = row['id']?.toString() ?? '';
    final title = row['title']?.toString();

    // Resolve patient name asynchronously; the notification call is also async.
    Future<void>(() async {
      String patientName = 'a patient';
      if (patientId != null && patientId.isNotEmpty) {
        try {
          final res = await Supabase.instance.client
              .from('patients')
              .select('full_name')
              .eq('id', patientId)
              .maybeSingle();
          final name = res?['full_name']?.toString();
          if (name != null && name.isNotEmpty) patientName = name;
        } catch (e) {
          debugPrint('followup_task: patient lookup failed: $e');
        }
      }

      if (assignedTo != null && assignedTo == currentUserId) {
        _addInAppNotification(
          id: 'followup-$taskId',
          title: 'New Follow-up Task',
          body: title?.isNotEmpty == true
              ? '$title · $patientName (due $dueDate)'
              : 'Follow-up for $patientName due $dueDate',
          type: 'followup_task',
        );

        NotificationService.instance.showFollowupNotification(
          patientName: patientName,
          dueDate: dueDate,
        );
      } else if (assignedTo != null) {
        FcmService.sendToDoctor(
          doctorId: assignedTo,
          title: 'New Follow-up Task',
          body: 'Follow-up for $patientName due $dueDate',
          data: {'type': 'followup_task', 'task_id': taskId},
        );
      }
    });
  }

  // ── patients update ───────────────────────────────────────────────────────

  void _handlePatientUpdate(
      PostgresChangePayload payload, String currentDoctorName) {
    try {
      final row = payload.newRecord;
      final updatedBy = row['last_updated_by']?.toString() ?? '';
      final newStatus = row['service_status']?.toString() ?? '';
      final oldStatus = payload.oldRecord['service_status']?.toString();

      if (updatedBy == currentDoctorName) return;
      if (newStatus.isEmpty || oldStatus == newStatus) return;

      NotificationService.instance.showPatientUpdateNotification(
        patientName: row['full_name']?.toString() ?? 'A patient',
        updatedBy: updatedBy,
        newStatus: newStatus,
      );

      _addInAppNotification(
        id: 'status-${row['id']}-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Status Updated: ${row['full_name'] ?? 'Patient'}',
        body: '$oldStatus → $newStatus (by $updatedBy)',
        type: 'status_change',
      );
    } catch (e) {
      debugPrint('Error handling patient update: $e');
    }
  }

  // ── patients insert ───────────────────────────────────────────────────────

  void _handlePatientInsert(
      PostgresChangePayload payload, String currentDoctorName) {
    try {
      final row = payload.newRecord;
      final addedBy = row['last_updated_by']?.toString() ?? '';
      if (addedBy.isNotEmpty && addedBy != currentDoctorName) {
        NotificationService.instance.showNewPatientNotification(
          patientName: row['full_name']?.toString() ?? 'A patient',
          addedBy: addedBy,
        );
      }
    } catch (e) {
      debugPrint('Error handling patient insert: $e');
    }
  }

  // ── visits update ─────────────────────────────────────────────────────────

  void _handleVisitUpdate(
      PostgresChangePayload payload, String currentDoctorName) {
    try {
      final row = payload.newRecord;
      final updatedBy = row['last_updated_by']?.toString() ?? '';
      if (updatedBy.isNotEmpty && updatedBy != currentDoctorName) {
        NotificationService.instance.showPatientUpdateNotification(
          patientName: row['patient_name']?.toString() ?? 'A patient',
          updatedBy: updatedBy,
          newStatus: row['patient_flow_status']?.toString() ?? 'Updated',
        );
      }
    } catch (e) {
      debugPrint('Error handling visit update: $e');
    }
  }

  void _handleFollowupUpdate(PostgresChangePayload payload) {
    try {
      final row = payload.newRecord;
      final oldStatus = payload.oldRecord['status']?.toString();
      final newStatus = row['status']?.toString();
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final createdBy = row['created_by']?.toString();
      final assignedTo = row['assigned_to']?.toString();
      final taskId = row['id']?.toString() ?? '';

      if (newStatus == null || newStatus.isEmpty || oldStatus == newStatus) {
        return;
      }

      // ── Assistant marked the task completed → notify the assigning doctor.
      // Only fires on the assigning doctor's session (createdBy == me) and
      // only when the status flips into 'completed' from something else.
      if (newStatus == 'completed' &&
          oldStatus != 'completed' &&
          createdBy == currentUserId &&
          assignedTo != currentUserId) {
        _addInAppNotification(
          id: 'fu-completed-$taskId',
          title: 'Follow-up completed',
          body: 'An assistant completed a follow-up. Tap to review.',
          type: 'followup_review_needed',
        );
        NotificationService.instance.showFollowupNotification(
          patientName: row['patient_name']?.toString() ?? 'a patient',
          dueDate: 'completed',
        );
        // Best-effort FCM push for offline doctors. createdBy is the doctor's
        // own user id, so this lights up their other devices too.
        if (createdBy != null && createdBy.isNotEmpty) {
          FcmService.sendToDoctor(
            doctorId: createdBy,
            title: 'Follow-up completed',
            body: 'An assistant completed a follow-up. Open MediFlow to review.',
            data: {
              'type': 'followup_review_needed',
              'task_id': taskId,
            },
          );
        }
        return;
      }

      // ── Doctor finished review → notify the assistant who did the work.
      if (createdBy == currentUserId) return; // doctor's own update, ignore
      if (assignedTo != currentUserId) return; // not for me

      _addInAppNotification(
        id: 'fu-update-$taskId-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Follow-up Updated',
        body: 'A follow-up task is now: $newStatus',
        type: 'followup_update',
      );
      NotificationService.instance.showFollowupNotification(
        patientName: row['patient_name']?.toString() ?? 'a patient',
        dueDate: newStatus,
      );
    } catch (e) {
      debugPrint('Error handling followup update: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _addInAppNotification({
    required String id,
    required String title,
    required String body,
    required String type,
  }) {
    final container = _container;
    if (container == null) return;
    try {
      container.read(notificationProvider.notifier).addNotification(
            AppNotification(
              id: id,
              title: title,
              body: body,
              timestamp: DateTime.now(),
              type: type,
            ),
          );
    } catch (e) {
      debugPrint('RealtimeService: addInAppNotification failed: $e');
    }
  }

  void dispose() {
    try {
      _channel?.unsubscribe();
    } catch (_) {}
    _channel = null;
    _isSubscribed = false;
    _currentDoctorName = null;
    _container = null;
  }
}
