// lib/features/agent_visits/agent_outside_visit_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/error_handler.dart';
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
          .select('*, patients(full_name)')
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
    required String patientId,
    String? followupTaskId,
    required String extDoctorName,
    String? extDoctorSpecialization,
    String? extDoctorHospital,
    String? extDoctorPhone,
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

    String dateStr(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final data = <String, dynamic>{
      'patient_id': patientId,
      'agent_id': user.id,
      if (followupTaskId != null) 'followup_task_id': followupTaskId,
      'ext_doctor_name': extDoctorName,
      if (extDoctorSpecialization != null && extDoctorSpecialization.isNotEmpty)
        'ext_doctor_specialization': extDoctorSpecialization,
      if (extDoctorHospital != null && extDoctorHospital.isNotEmpty)
        'ext_doctor_hospital': extDoctorHospital,
      if (extDoctorPhone != null && extDoctorPhone.isNotEmpty)
        'ext_doctor_phone': extDoctorPhone,
      'visit_date': dateStr(visitDate),
      if (chiefComplaint != null && chiefComplaint.isNotEmpty)
        'chief_complaint': chiefComplaint,
      if (diagnosis != null && diagnosis.isNotEmpty) 'diagnosis': diagnosis,
      if (prescriptions != null && prescriptions.isNotEmpty)
        'prescriptions': prescriptions,
      if (visitNotes != null && visitNotes.isNotEmpty)
        'visit_notes': visitNotes,
      if (nextFollowupDate != null)
        'next_followup_date': dateStr(nextFollowupDate),
      if (meetDrName != null && meetDrName.isNotEmpty)
        'meet_dr_name': meetDrName,
      if (meetPlace != null && meetPlace.isNotEmpty) 'meet_place': meetPlace,
      if (meetDrType != null) 'meet_dr_type': meetDrType,
      if (meetTimesVisited != null) 'meet_times_visited': meetTimesVisited,
    };

    try {
      await _supabase.retry(() => _supabase.from('agent_outside_visits').insert(data));

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
        .select('*, patients(full_name)')
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
        .select('*, patients(full_name)')
        .order('visit_date', ascending: false));

    return (response as List)
        .map((j) =>
            AgentOutsideVisit.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList();
  } catch (e) {
    throw Exception(AppError.getMessage(e));
  }
});
