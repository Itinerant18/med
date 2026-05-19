// lib/features/agent_visits/agent_outside_visit_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/push_notification_service.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/features/followups/followup_provider.dart';
import 'package:mediflow/models/agent_outside_visit_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final agentOutsideVisitsProvider = AsyncNotifierProvider.autoDispose<
    AgentOutsideVisitsNotifier, List<AgentOutsideVisit>>(
  AgentOutsideVisitsNotifier.new,
);

class AgentOutsideVisitsNotifier
    extends AutoDisposeAsyncNotifier<List<AgentOutsideVisit>> {
  SupabaseClient get _supabase => ref.read(supabaseClientProvider);

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static const _selectColumns = '''
    id,
    patient_id,
    followup_task_id,
    agent_id,
    ext_doctor_name,
    ext_doctor_specialization,
    ext_doctor_hospital,
    ext_doctor_phone,
    area_district,
    visit_date,
    chief_complaint,
    diagnosis,
    prescriptions,
    visit_notes,
    next_followup_date,
    meet_dr_name,
    meet_place,
    meet_dr_type,
    meet_times_visited,
    status,
    reviewed_by,
    reviewed_at,
    created_at,
    patients(full_name)
  ''';

  @override
  Future<List<AgentOutsideVisit>> build() async {
    return _fetch();
  }

  Future<List<AgentOutsideVisit>> _fetch() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _supabase.retry(() => _supabase
          .from('agent_outside_visits')
          .select(_selectColumns)
          .eq('agent_id', user.id)
          .order('visit_date', ascending: false)
          .order('created_at', ascending: false));

      return (response as List)
          .map((j) =>
              AgentOutsideVisit.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> createVisit({
    String? patientId,
    String? followupTaskId,
    required String extDoctorName,
    String? extDoctorSpecialization,
    String? extDoctorHospital,
    String? extDoctorPhone,
    String? areaDistrict,
    required DateTime visitDate,
    String? chiefComplaint,
    String? diagnosis,
    String? prescriptions,
    String? visitNotes,
    DateTime? nextFollowupDate,
    String? meetDrName,
    String? meetPlace,
    String? meetDrType,
    int? meetTimesVisited,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated.');

    final data = <String, dynamic>{
      if (patientId != null && patientId.isNotEmpty) 'patient_id': patientId,
      'agent_id': user.id,
      if (followupTaskId != null) 'followup_task_id': followupTaskId,
      'ext_doctor_name': extDoctorName,
      if (extDoctorSpecialization != null && extDoctorSpecialization.isNotEmpty)
        'ext_doctor_specialization': extDoctorSpecialization,
      if (extDoctorHospital != null && extDoctorHospital.isNotEmpty)
        'ext_doctor_hospital': extDoctorHospital,
      if (extDoctorPhone != null && extDoctorPhone.isNotEmpty)
        'ext_doctor_phone': extDoctorPhone,
      if (areaDistrict != null && areaDistrict.isNotEmpty)
        'area_district': areaDistrict,
      'visit_date': _dateStr(visitDate),
      if (chiefComplaint != null && chiefComplaint.isNotEmpty)
        'chief_complaint': chiefComplaint,
      if (diagnosis != null && diagnosis.isNotEmpty) 'diagnosis': diagnosis,
      if (prescriptions != null && prescriptions.isNotEmpty)
        'prescriptions': prescriptions,
      if (visitNotes != null && visitNotes.isNotEmpty)
        'visit_notes': visitNotes,
      if (nextFollowupDate != null)
        'next_followup_date': _dateStr(nextFollowupDate),
      if (meetDrName != null && meetDrName.isNotEmpty)
        'meet_dr_name': meetDrName,
      if (meetPlace != null && meetPlace.isNotEmpty) 'meet_place': meetPlace,
      if (meetDrType != null) 'meet_dr_type': meetDrType,
      if (meetTimesVisited != null) 'meet_times_visited': meetTimesVisited,
    };

    // Query the task creator before insert (best-effort) for push notification.
    String? taskCreatedBy;
    if (followupTaskId != null) {
      try {
        final taskRes = await _supabase
            .from('followup_tasks')
            .select('created_by')
            .eq('id', followupTaskId)
            .maybeSingle();
        taskCreatedBy = taskRes?['created_by']?.toString();
      } catch (_) {
        // Best-effort.
      }
    }

    try {
      final insertedVisit = await _supabase.retry(() => _supabase
          .from('agent_outside_visits')
          .insert(data)
          .select('id')
          .maybeSingle());
      final createdVisitId = insertedVisit?['id']?.toString();

      // If tied to a follow-up task, mark it complete via the canonical
      // FollowupTasksNotifier so:
      //  • the same write path is used everywhere (no schema drift),
      //  • the follow-ups list refreshes immediately after completion, and
      //  • there's a single owner for the "external doctor" write — preventing
      //    the previous race where two providers both wrote to the same row.
      if (followupTaskId != null) {
        await ref.read(followupTasksProvider.notifier).completeTask(
              followupTaskId,
              isExternalDoctor: true,
              extDoctorName: extDoctorName,
              extDoctorSpecialization: extDoctorSpecialization,
              extDoctorHospital: extDoctorHospital,
              extDoctorPhone: extDoctorPhone,
              completionNotes: visitNotes,
            );
      }

      // Auto-create a self-assigned follow-up task so the agent is reminded
      // to re-visit this external doctor on the chosen date.
      if (nextFollowupDate != null) {
        final hospLabel = (extDoctorHospital != null && extDoctorHospital.isNotEmpty)
            ? ' at $extDoctorHospital'
            : '';
        await _supabase.retry(() => _supabase.from('followup_tasks').insert({
              if (patientId != null && patientId.isNotEmpty)
                'patient_id': patientId,
              'assigned_to': user.id,
              'created_by': user.id,
              'due_date': _dateStr(nextFollowupDate),
              'title': 'Re-visit Dr. $extDoctorName',
              'notes':
                  'Self-reminder: Follow up with Dr. $extDoctorName$hospLabel',
              'priority': 'normal',
              'status': 'pending',
              'is_external_doctor': true,
              if (extDoctorName.isNotEmpty)
                'target_ext_doctor_name': extDoctorName,
              if (extDoctorSpecialization != null &&
                  extDoctorSpecialization.isNotEmpty)
                'target_ext_doctor_specialization': extDoctorSpecialization,
              if (extDoctorHospital != null && extDoctorHospital.isNotEmpty)
                'target_ext_doctor_hospital': extDoctorHospital,
              if (extDoctorPhone != null && extDoctorPhone.isNotEmpty)
                'target_ext_doctor_phone': extDoctorPhone,
              'scheduled_visit_date': _dateStr(nextFollowupDate),
            }));
        // Refresh the followup tasks list so the new reminder shows up.
        ref.invalidate(followupTasksProvider);
      }

      ref.invalidateSelf();

      // ── Push notification to task creator ──
      if (taskCreatedBy != null) {
        try {
          await PushNotificationService.sendNotification(
            ref: ref,
            event: 'outside_visit_recorded',
            recipientIds: [taskCreatedBy],
            title: 'Visit recorded',
            body: 'Agent recorded an external doctor visit for $extDoctorName',
            data: {
              'entityType': 'agent_outside_visit',
              if (createdVisitId != null && createdVisitId.isNotEmpty)
                'entityId': createdVisitId,
            },
          );
        } catch (_) {
          // Best-effort.
        }
      }
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }

  Future<void> updateVisit({
    required String visitId,
    required DateTime visitDate,
    required String extDoctorName,
    String? extDoctorSpecialization,
    String? extDoctorHospital,
    String? extDoctorPhone,
    String? areaDistrict,
    String? meetDrType,
    int? meetTimesVisited,
    String? chiefComplaint,
    String? diagnosis,
    String? prescriptions,
    String? visitNotes,
    DateTime? nextFollowupDate,
    bool scheduleNewTask = false,
    String? patientId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated.');

    final data = <String, dynamic>{
      'ext_doctor_name': extDoctorName,
      'visit_date': _dateStr(visitDate),
      'ext_doctor_specialization':
          extDoctorSpecialization != null && extDoctorSpecialization.isNotEmpty
              ? extDoctorSpecialization
              : null,
      'ext_doctor_hospital':
          extDoctorHospital != null && extDoctorHospital.isNotEmpty
              ? extDoctorHospital
              : null,
      'ext_doctor_phone':
          extDoctorPhone != null && extDoctorPhone.isNotEmpty
              ? extDoctorPhone
              : null,
      'area_district':
          areaDistrict != null && areaDistrict.isNotEmpty
              ? areaDistrict
              : null,
      'meet_dr_type': meetDrType,
      'meet_times_visited': meetTimesVisited,
      'chief_complaint':
          chiefComplaint != null && chiefComplaint.isNotEmpty
              ? chiefComplaint
              : null,
      'diagnosis':
          diagnosis != null && diagnosis.isNotEmpty ? diagnosis : null,
      'prescriptions':
          prescriptions != null && prescriptions.isNotEmpty
              ? prescriptions
              : null,
      'visit_notes':
          visitNotes != null && visitNotes.isNotEmpty ? visitNotes : null,
      'next_followup_date': nextFollowupDate != null ? _dateStr(nextFollowupDate) : null,
    };

    try {
      await _supabase.retry(() => _supabase
          .from('agent_outside_visits')
          .update(data)
          .eq('id', visitId)
          .eq('agent_id', user.id));

      if (scheduleNewTask && nextFollowupDate != null) {
        final hospLabel = (extDoctorHospital != null && extDoctorHospital.isNotEmpty)
            ? ' at $extDoctorHospital'
            : '';
        await _supabase.retry(() => _supabase.from('followup_tasks').insert({
              if (patientId != null && patientId.isNotEmpty)
                'patient_id': patientId,
              'assigned_to': user.id,
              'created_by': user.id,
              'due_date': _dateStr(nextFollowupDate),
              'title': 'Re-visit Dr. $extDoctorName',
              'notes':
                  'Self-reminder: Follow up with Dr. $extDoctorName$hospLabel',
              'priority': 'normal',
              'status': 'pending',
              'is_external_doctor': true,
              if (extDoctorName.isNotEmpty)
                'target_ext_doctor_name': extDoctorName,
              if (extDoctorSpecialization != null &&
                  extDoctorSpecialization.isNotEmpty)
                'target_ext_doctor_specialization': extDoctorSpecialization,
              if (extDoctorHospital != null && extDoctorHospital.isNotEmpty)
                'target_ext_doctor_hospital': extDoctorHospital,
              if (extDoctorPhone != null && extDoctorPhone.isNotEmpty)
                'target_ext_doctor_phone': extDoctorPhone,
              'scheduled_visit_date': _dateStr(nextFollowupDate),
            }));
        ref.invalidate(followupTasksProvider);
      }

      ref.invalidateSelf();
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }

  Future<void> deleteVisit(String visitId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated.');

    try {
      await _supabase.retry(() => _supabase
          .from('agent_outside_visits')
          .delete()
          .eq('id', visitId)
          .eq('agent_id', user.id));
      ref.invalidateSelf();
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }
}

// Fetches the AgentOutsideVisit linked to a given follow-up task (if any).
// Used by the doctor's review screen to show what the assistant recorded.
final agentOutsideVisitForTaskProvider = FutureProvider.autoDispose
    .family<AgentOutsideVisit?, String>((ref, taskId) async {
  if (taskId.isEmpty) return null;
  final supabase = ref.read(supabaseClientProvider);
  try {
    final response = await supabase.retry(() => supabase
        .from('agent_outside_visits')
        .select(AgentOutsideVisitsNotifier._selectColumns)
        .eq('followup_task_id', taskId)
        .maybeSingle());
    if (response == null) return null;
    return AgentOutsideVisit.fromJson(Map<String, dynamic>.from(response));
  } catch (e) {
    throw Exception(AppError.getMessage(e));
  }
});

// Provider for doctor / head-doctor to view all agent outside visits.
final allAgentOutsideVisitsProvider =
    FutureProvider.autoDispose<List<AgentOutsideVisit>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
    try {
      final response = await supabase.retry(() => supabase
          .from('agent_outside_visits')
          .select(AgentOutsideVisitsNotifier._selectColumns)
        .order('visit_date', ascending: false));

    return (response as List)
        .map((j) =>
            AgentOutsideVisit.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList();
  } catch (e) {
    throw Exception(AppError.getMessage(e));
  }
});

// Reads the `known_external_doctors` view for the doctor to pick a previously
// visited external doctor and pre-fill the assignment form.
final knownExternalDoctorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  try {
    final response = await supabase.retry(() => supabase
        .from('known_external_doctors')
        .select(
            'ext_doctor_name, ext_doctor_specialization, ext_doctor_hospital, ext_doctor_phone, area_district, visit_count, last_visit_date')
        .order('last_visit_date', ascending: false));
    return (response as List)
        .map((j) => Map<String, dynamic>.from(j as Map))
        .toList();
  } catch (e) {
    throw Exception(AppError.getMessage(e));
  }
});

final agentOutsideVisitByIdProvider =
    FutureProvider.autoDispose.family<AgentOutsideVisit?, String>((
  ref,
  visitId,
) async {
  if (visitId.isEmpty) return null;
  final supabase = ref.read(supabaseClientProvider);
  try {
    final response = await supabase.retry(() => supabase
        .from('agent_outside_visits')
        .select(AgentOutsideVisitsNotifier._selectColumns)
        .eq('id', visitId)
        .maybeSingle());
    if (response == null) return null;
    return AgentOutsideVisit.fromJson(Map<String, dynamic>.from(response));
  } catch (e) {
    throw Exception(AppError.getMessage(e));
  }
});
