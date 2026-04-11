import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediflow/core/notification_service.dart';

class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  StreamSubscription<List<Map<String, dynamic>>>? _patientsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _visitsSub;

  void subscribeToPatientChanges(String currentDoctorName) {
    final supabase = Supabase.instance.client;
    Map<String, Map<String, dynamic>> previousPatients = {};

    _patientsSub?.cancel();
    _patientsSub = supabase.from('patients').stream(primaryKey: ['id']).listen((patients) {
      for (final patient in patients) {
        final id = patient['id'].toString();
        final lastUpdatedBy = patient['last_updated_by']?.toString();
        final patientName = patient['full_name']?.toString() ?? 'Unknown Patient';
        final newStatus = patient['service_status']?.toString() ?? 'Pending';

        if (lastUpdatedBy != null && lastUpdatedBy != currentDoctorName) {
          if (!previousPatients.containsKey(id)) {
            // It's an insert, but we only notify if previousPatients is not empty 
            // (meaning this is not the initial data load)
            if (previousPatients.isNotEmpty) {
              NotificationService.instance.showNewPatientNotification(
                patientName: patientName,
                addedBy: lastUpdatedBy,
              );
            }
          } else {
            // It's an update
            final previousStatus = previousPatients[id]?['service_status'];
            final previousUpdatedBy = previousPatients[id]?['last_updated_by'];
            
            if (newStatus != previousStatus || lastUpdatedBy != previousUpdatedBy) {
               NotificationService.instance.showPatientUpdateNotification(
                 patientName: patientName,
                 updatedBy: lastUpdatedBy,
                 newStatus: newStatus,
               );
            }
          }
        }
        previousPatients[id] = patient;
      }
    });
  }

  void subscribeToVisitChanges(String currentDoctorName) {
    final supabase = Supabase.instance.client;
    Map<String, Map<String, dynamic>> previousVisits = {};

    _visitsSub?.cancel();
    _visitsSub = supabase.from('visits').stream(primaryKey: ['id']).listen((visits) async {
      for (final visit in visits) {
        final id = visit['id'].toString();
        final lastUpdatedBy = visit['last_updated_by']?.toString();
        final patientId = visit['patient_id']?.toString();
        final status = visit['patient_flow_status']?.toString() ?? visit['test_status']?.toString() ?? 'Updated';

        if (lastUpdatedBy != null && lastUpdatedBy != currentDoctorName) {
          if (previousVisits.containsKey(id)) {
            final prevUpdatedBy = previousVisits[id]?['last_updated_by'];
            
            if (lastUpdatedBy != prevUpdatedBy) {
              String patientName = 'Unknown Patient';
              if (patientId != null) {
                final patientRes = await supabase.from('patients').select('full_name').eq('id', patientId).maybeSingle();
                if (patientRes != null && patientRes['full_name'] != null) {
                  patientName = patientRes['full_name'];
                }
              }

              NotificationService.instance.showPatientUpdateNotification(
                patientName: patientName,
                updatedBy: lastUpdatedBy,
                newStatus: status,
              );
            }
          }
        }
        previousVisits[id] = visit;
      }
    });
  }

  void dispose() {
    _patientsSub?.cancel();
    _visitsSub?.cancel();
  }
}
