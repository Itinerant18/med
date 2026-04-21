import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/models/visit_model.dart';
import 'package:mediflow/models/user_role.dart';

final drVisitsProvider = AsyncNotifierProvider<DrVisitsNotifier, List<DrVisit>>(
    DrVisitsNotifier.new); final drVisitByIdProvider = Provider.family<DrVisit?, String>((ref, id) { final list = ref.watch(drVisitsProvider).valueOrNull; if (list == null) return null; for (final v in list) { if (v.id == id) return v; } return null; });

class DrVisitsNotifier extends AsyncNotifier<List<DrVisit>> {
  @override
  Future<List<DrVisit>> build() async {
    return _fetchVisits();
  }

  Future<List<DrVisit>> _fetchVisits() async {
    final supabase = ref.read(supabaseClientProvider);
    final userState = ref.read(authNotifierProvider).value;
    final role = ref.read(currentRoleProvider);

    var query = supabase.from('dr_visits').select('''
      *,
      patients:patient_id(full_name)
    ''');

    if (role == UserRole.assistant && userState != null) {
      query = query.eq('assigned_agent_id', userState.session.user.id);
    }

    final response = await query.order('visit_date', ascending: false);
    final rows = (response as List)
        .map((json) => Map<String, dynamic>.from(json as Map))
        .toList();

    final agentIds = rows
        .map((row) => row['assigned_agent_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final agentNames = <String, String>{};
    if (agentIds.isNotEmpty) {
      final agentResponse = await supabase
          .from('doctors')
          .select('id, full_name')
          .inFilter('id', agentIds);

      for (final row in agentResponse as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = map['id']?.toString();
        final fullName = map['full_name']?.toString();
        if (id != null && fullName != null) {
          agentNames[id] = fullName;
        }
      }
    }

    return rows.map((row) {
      final assignedAgentId = row['assigned_agent_id']?.toString();
      if (assignedAgentId != null && agentNames.containsKey(assignedAgentId)) {
        row['agent'] = {'full_name': agentNames[assignedAgentId]};
      }
      return DrVisit.fromJson(row);
    }).toList();
  }

  Future<void> createVisit({
    required String patientId,
    required String? assignedAgentId,
    required bool isExternal,
    String? extDoctorName,
    String? extDoctorSpecialization,
    String? extDoctorHospital,
    String? extDoctorPhone,
    required String visitNotes,
    required String diagnosis,
    required DateTime? followupDate,
    required String followupNotes,
  }) async {
    final supabase = ref.read(supabaseClientProvider);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final visitResponse = await supabase
        .from('dr_visits')
        .insert({
          'patient_id': patientId,
          'doctor_id': user.id,
          'assigned_agent_id': isExternal ? null : assignedAgentId,
          'visit_notes': visitNotes,
          'diagnosis': diagnosis,
          'followup_date': followupDate?.toIso8601String().split('T')[0],
          'followup_notes': followupNotes,
          'created_by_id': user.id,
          'is_external_doctor': isExternal,
          if (isExternal) 'ext_doctor_name': extDoctorName,
          if (isExternal)
            'ext_doctor_specialization': extDoctorSpecialization,
          if (isExternal) 'ext_doctor_hospital': extDoctorHospital,
          if (isExternal) 'ext_doctor_phone': extDoctorPhone,
        })
        .select()
        .single();

    if (!isExternal && followupDate != null && assignedAgentId != null) {
      await supabase.from('followup_tasks').insert({
        'patient_id': patientId,
        'dr_visit_id': visitResponse['id'],
        'assigned_to': assignedAgentId,
        'created_by': user.id,
        'due_date': followupDate.toIso8601String().split('T')[0],
        'notes': followupNotes,
      });
    }

    ref.invalidateSelf();
  }

  Future<void> updateStatus(String visitId, String status) async {
    final supabase = ref.read(supabaseClientProvider);
    await supabase.from('dr_visits').update({
      'status': status,
      'last_updated_at': DateTime.now().toIso8601String(),
    }).eq('id', visitId);

    ref.invalidateSelf();
  }

  Future<void> updateFollowupStatus(
      String visitId, String followupStatus) async {
    final supabase = ref.read(supabaseClientProvider);
    await supabase.from('dr_visits').update({
      'followup_status': followupStatus,
      'last_updated_at': DateTime.now().toIso8601String(),
    }).eq('id', visitId);

    ref.invalidateSelf();
  }
}
