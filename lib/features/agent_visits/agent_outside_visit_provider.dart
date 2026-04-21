// lib/features/agent_visits/agent_outside_visit_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/supabase_client.dart';
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

    final response = await _supabase
        .from('agent_outside_visits')
        .select('*, patients(full_name)')
        .eq('agent_id', user.id)
        .order('visit_date', ascending: false)
        .order('created_at', ascending: false);

    return (response as List)
        .map((j) =>
            AgentOutsideVisit.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList();
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
    };

    await _supabase.from('agent_outside_visits').insert(data);

    // If tied to a follow-up task, mark it complete.
    if (followupTaskId != null) {
      await _supabase.from('followup_tasks').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
        'is_external_doctor': true,
        'ext_doctor_name': extDoctorName,
        'ext_doctor_specialization': extDoctorSpecialization,
        'ext_doctor_hospital': extDoctorHospital,
        'ext_doctor_phone': extDoctorPhone,
        'completion_notes': visitNotes,
      }).eq('id', followupTaskId);
    }

    ref.invalidateSelf();
  }
}

// Provider for doctor / head-doctor to view all agent outside visits.
final allAgentOutsideVisitsProvider =
    FutureProvider.autoDispose<List<AgentOutsideVisit>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final response = await supabase
      .from('agent_outside_visits')
      .select('*, patients(full_name)')
      .order('visit_date', ascending: false);

  return (response as List)
      .map((j) =>
          AgentOutsideVisit.fromJson(Map<String, dynamic>.from(j as Map)))
      .toList();
});
