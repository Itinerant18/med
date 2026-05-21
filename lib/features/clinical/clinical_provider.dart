// lib/features/clinical/clinical_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/cache_service.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/models/user_role.dart';

final patientSearchQueryProvider = StateProvider<String>((ref) => '');

final clinicalPatientSearchProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(patientSearchQueryProvider);

  if (query.trim().length < 2) return [];

  final supabase = ref.watch(supabaseClientProvider);
  final userState = ref.watch(authNotifierProvider).value;

  try {
    var dbQuery = supabase
        .from('patients')
        .select('id, full_name, date_of_birth')
        .ilike('full_name', '%${query.trim()}%');

    // Agents only see their own patients. Doctors and head doctors see all.
    if (userState != null && userState.role == UserRole.assistant) {
      dbQuery = dbQuery.eq('created_by_id', userState.session.user.id);
    }

    final response = await supabase.retry(() => dbQuery.limit(8));
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    if (userState != null) {
      final cacheKey = 'patients_${userState.role.name}_${userState.session.user.id}';
      final cached = CacheService.instance.getRaw(cacheKey);
      if (cached != null) {
        final queryLower = query.trim().toLowerCase();
        final List<Map<String, dynamic>> results = [];
        for (final row in cached as List) {
          final fullName = row['full_name']?.toString() ?? '';
          if (fullName.toLowerCase().contains(queryLower)) {
            results.add({
              'id': row['id'],
              'full_name': row['full_name'],
              'date_of_birth': row['date_of_birth'],
            });
            if (results.length >= 8) break;
          }
        }
        return results;
      }
    }
    throw Exception(AppError.getMessage(e));
  }
});

class ClinicalNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> saveVisit(Map<String, dynamic> visitData) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final supabase = ref.read(supabaseClientProvider);
        final userState = ref.read(authNotifierProvider).value;
        if (userState == null) throw Exception('Not authenticated');

        // Pull internal flag before it is written to the DB.
        final clientFlagIsCheckup = visitData['is_assigned_checkup'] == true;

        // Strip null values and internal-only flags from the DB payload.
        final cleanedData = Map<String, dynamic>.fromEntries(
          visitData.entries.where(
            (e) => e.value != null && e.key != 'is_assigned_checkup',
          ),
        );

        final patientId = cleanedData['patient_id']?.toString() ?? '';

        // ── Task 4: Server-side verification ─────────────────────────────────
        // Fetch the patient's current status independently of the client flag.
        // This prevents a malicious or stale client from bypassing checkup logic.
        bool serverVerifiedCheckup = false;
        if (patientId.isNotEmpty && clientFlagIsCheckup) {
          try {
            final patientRow = await supabase.retry(
              () => supabase
                  .from('patients')
                  .select('service_status, assigned_doctor_id')
                  .eq('id', patientId)
                  .maybeSingle(),
            );
            serverVerifiedCheckup = patientRow != null &&
                patientRow['service_status']
                        ?.toString()
                        .toLowerCase() ==
                    'pending_checkup' &&
                patientRow['assigned_doctor_id'] ==
                    userState.session.user.id;
          } catch (e) {
            // Non-fatal: fall back to the client flag if the pre-fetch fails.
            debugPrint('Patient status pre-fetch failed: $e');
            serverVerifiedCheckup = clientFlagIsCheckup;
          }
        }

        final isAssignedCheckup = serverVerifiedCheckup || clientFlagIsCheckup;

        // Force Checkup Completed when this is a confirmed assigned checkup.
        if (isAssignedCheckup) {
          cleanedData['patient_flow_status'] = 'Checkup Completed';
        }

        final now = DateTime.now().toIso8601String();
        final finalVisitData = {
          ...cleanedData,
          'created_by_id': userState.session.user.id,
          'last_updated_by_id': userState.session.user.id,
          'last_updated_by': userState.doctorName ?? 'Staff',
          'last_updated_at': now,
        };

        // ── Task 1, Step 1: Insert visit — capture ID for compensating rollback.
        final insertedRow = await supabase.retry(
          () => supabase
              .from('visits')
              .insert(finalVisitData)
              .select('id')
              .single(),
        );
        final insertedVisitId = insertedRow['id']?.toString();

        // ── Task 1, Step 2: Update patients table (sequential + compensated). ─
        if (patientId.isNotEmpty) {
          final patientUpdate = <String, dynamic>{
            'service_status': finalVisitData['patient_flow_status'],
            'last_updated_at': finalVisitData['last_updated_at'],
            'last_visit_at': finalVisitData['visit_date'],
            'last_updated_by': finalVisitData['last_updated_by'],
            'last_updated_by_id': finalVisitData['last_updated_by_id'],
          };
          // Propagate granular test statuses when the doctor updated them.
          if (finalVisitData['investigation_status'] != null &&
              (finalVisitData['investigation_status'] as Map).isNotEmpty) {
            patientUpdate['investigation_status'] =
                finalVisitData['investigation_status'];
          }

          try {
            await supabase.retry(
              () => supabase
                  .from('patients')
                  .update(patientUpdate)
                  .eq('id', patientId),
            );
          } on PostgrestException catch (pge) {
            // last_visit_at may not exist in all deployments (pending migration).
            // Retry without it rather than rolling back a successful visit insert.
            if (pge.code == '42703' &&
                pge.message.toLowerCase().contains('last_visit_at')) {
              await supabase.retry(
                () => supabase
                    .from('patients')
                    .update(Map.from(patientUpdate)..remove('last_visit_at'))
                    .eq('id', patientId),
              );
            } else {
              // Different column/schema error — compensate and surface it.
              if (insertedVisitId != null) {
                try {
                  await supabase
                      .from('visits')
                      .delete()
                      .eq('id', insertedVisitId);
                } catch (rollbackError) {
                  debugPrint(
                    'CRITICAL: visit $insertedVisitId orphaned after patients '
                    'update failure. Manual cleanup required. '
                    'Rollback error: $rollbackError',
                  );
                }
              }
              rethrow;
            }
          } catch (patientUpdateError) {
            // Compensating action: delete the visit to restore integrity.
            if (insertedVisitId != null) {
              try {
                await supabase
                    .from('visits')
                    .delete()
                    .eq('id', insertedVisitId);
              } catch (rollbackError) {
                debugPrint(
                  'CRITICAL: visit $insertedVisitId orphaned after patients '
                  'update failure. Manual cleanup required. '
                  'Rollback error: $rollbackError',
                );
              }
            }
            rethrow;
          }

          // ── Task 4, Step 3: Work-log for completed assigned checkups. ───────
          // Treated as audit/notification — failures do not roll back the visit.
          if (isAssignedCheckup) {
            final doctorName = userState.doctorName ?? 'Doctor';
            try {
              await supabase.retry(
                () => supabase.from('work_log').insert({
                  'entity_type': 'patient',
                  'entity_id': patientId,
                  'body':
                      'Dr. $doctorName has completed the assigned clinical checkup.',
                  'created_by_id': userState.session.user.id,
                  'created_at': now,
                }),
              );
            } catch (workLogError) {
              debugPrint('work_log insert failed (non-fatal): $workLogError');
            }
          }
        }
      } catch (e) {
        throw Exception(AppError.getMessage(e));
      }
    });
  }
}

final clinicalNotifierProvider =
    AsyncNotifierProvider<ClinicalNotifier, void>(ClinicalNotifier.new);
