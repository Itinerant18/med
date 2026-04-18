// lib/core/realtime_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediflow/core/notification_service.dart';
import 'package:mediflow/core/notification_provider.dart';
import 'package:mediflow/models/app_notification.dart';

class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  RealtimeChannel? _channel;
  String? _currentDoctorName;
  bool _isSubscribed = false;
  Ref? _ref;

  void subscribeToPatientChanges(String currentDoctorName, Ref ref) {
    // Avoid re-subscribing if same doctor is already subscribed
    if (_isSubscribed && _currentDoctorName == currentDoctorName) {
      _ref = ref;
      return;
    }

    _ref = ref;
    _currentDoctorName = currentDoctorName;
    _channel?.unsubscribe();
    _isSubscribed = false;

    try {
      _channel = Supabase.instance.client
          .channel('mediflow-db-changes-${currentDoctorName.hashCode}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'patients',
            callback: (payload) {
              _handlePatientUpdate(payload, currentDoctorName);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'patients',
            callback: (payload) {
              _handlePatientInsert(payload, currentDoctorName);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'visits',
            callback: (payload) {
              _handleVisitUpdate(payload, currentDoctorName);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'dr_visits',
            callback: (payload) {
              _handleDrVisitInsert(payload);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'followup_tasks',
            callback: (payload) {
              _handleFollowupTaskInsert(payload);
            },
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

  void _handleDrVisitInsert(PostgresChangePayload payload) {
    try {
      final row = payload.newRecord;
      final assignedAgentId = row['assigned_agent_id']?.toString();
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      if (assignedAgentId != null && assignedAgentId == currentUserId) {
        // Fetch doctor name for notification (or use a placeholder)
        final doctorId = row['doctor_id']?.toString() ?? 'Doctor';
        
        // In-app notification
        if (_ref != null) {
          final notification = AppNotification(
            id: 'visit-${row['id']}',
            title: 'New Visit Assigned',
            message: 'You have been assigned a new patient visit.',
            timestamp: DateTime.now(),
            type: NotificationType.update, // Or add a new type
          );
          _ref!.read(notificationProvider.notifier).addNotification(notification);
        }

        // Push notification
        NotificationService.instance.showVisitAssignedNotification(
          patientName: 'a patient', // Ideally fetch from patients table
          doctorName: 'your lead',
        );
      }
    } catch (e) {
      debugPrint('Error handling dr_visit insert: $e');
    }
  }

  void _handleFollowupTaskInsert(PostgresChangePayload payload) {
    try {
      final row = payload.newRecord;
      final assignedTo = row['assigned_to']?.toString();
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      if (assignedTo != null && assignedTo == currentUserId) {
        // In-app notification
        if (_ref != null) {
          final notification = AppNotification(
            id: 'followup-${row['id']}',
            title: 'New Follow-up Task',
            message: 'A new follow-up task has been assigned to you.',
            timestamp: DateTime.now(),
            type: NotificationType.update,
          );
          _ref!.read(notificationProvider.notifier).addNotification(notification);
        }

        // Push notification
        NotificationService.instance.showFollowupNotification(
          patientName: 'a patient',
          dueDate: row['due_date']?.toString() ?? 'soon',
        );
      }
    } catch (e) {
      debugPrint('Error handling followup_task insert: $e');
    }
  }

  void _handlePatientUpdate(
      PostgresChangePayload payload, String currentDoctorName) {
    try {
      final row = payload.newRecord;
      final updatedBy = row['last_updated_by']?.toString() ?? '';
      if (updatedBy.isNotEmpty && updatedBy != currentDoctorName) {
        NotificationService.instance.showPatientUpdateNotification(
          patientName: row['full_name']?.toString() ?? 'A patient',
          updatedBy: updatedBy,
          newStatus: row['service_status']?.toString() ?? 'Updated',
        );
      }
    } catch (e) {
      debugPrint('Error handling patient update: $e');
    }
  }

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

  void dispose() {
    try {
      _channel?.unsubscribe();
    } catch (_) {}
    _channel = null;
    _isSubscribed = false;
    _currentDoctorName = null;
  }
}