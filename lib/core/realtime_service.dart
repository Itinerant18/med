// lib/core/realtime_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediflow/core/notification_service.dart';

class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  RealtimeChannel? _channel;

  void subscribeToPatientChanges(String currentDoctorName) {
    _channel?.unsubscribe();

    _channel = Supabase.instance.client
        .channel('mediflow-db-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'patients',
          callback: (payload) {
            final row = payload.newRecord;
            final updatedBy = row['last_updated_by']?.toString() ?? '';
            if (updatedBy.isNotEmpty && updatedBy != currentDoctorName) {
              NotificationService.instance.showPatientUpdateNotification(
                patientName: row['full_name']?.toString() ?? 'A patient',
                updatedBy: updatedBy,
                newStatus: row['service_status']?.toString() ?? 'Updated',
              );
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'patients',
          callback: (payload) {
            final row = payload.newRecord;
            final addedBy = row['last_updated_by']?.toString() ?? '';
            if (addedBy.isNotEmpty && addedBy != currentDoctorName) {
              NotificationService.instance.showNewPatientNotification(
                patientName: row['full_name']?.toString() ?? 'A patient',
                addedBy: addedBy,
              );
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'visits',
          callback: (payload) {
            final row = payload.newRecord;
            final updatedBy = row['last_updated_by']?.toString() ?? '';
            if (updatedBy.isNotEmpty && updatedBy != currentDoctorName) {
              NotificationService.instance.showPatientUpdateNotification(
                patientName: row['patient_name']?.toString() ?? 'A patient',
                updatedBy: updatedBy,
                newStatus:
                    row['patient_flow_status']?.toString() ?? 'Updated',
              );
            }
          },
        )
        .subscribe((status, error) {
          if (error != null) {
            // Realtime is optional — app still works without it
          }
        });
  }

  void subscribeToVisitChanges(String currentDoctorName) {
    // Now handled inside subscribeToPatientChanges via single channel
  }

  void dispose() {
    _channel?.unsubscribe();
    _channel = null;
  }
}
