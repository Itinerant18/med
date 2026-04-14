// lib/core/realtime_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediflow/core/notification_service.dart';

class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  RealtimeChannel? _channel;
  String? _currentDoctorName;
  bool _isSubscribed = false;

  void subscribeToPatientChanges(String currentDoctorName) {
    // Avoid re-subscribing if same doctor is already subscribed
    if (_isSubscribed && _currentDoctorName == currentDoctorName) return;

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