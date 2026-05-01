// MIGRATION NEEDED
// ALTER TABLE dr_visits
//   ADD COLUMN IF NOT EXISTS lead_patient_name    TEXT,
//   ADD COLUMN IF NOT EXISTS lead_patient_phone   TEXT,
//   ADD COLUMN IF NOT EXISTS lead_patient_address TEXT,
//   ADD COLUMN IF NOT EXISTS lead_notes           TEXT,
//   ADD COLUMN IF NOT EXISTS lead_status          TEXT NOT NULL DEFAULT 'new_lead'
//     CHECK (lead_status IN ('new_lead','contacted','converted','not_interested')),
//   ADD COLUMN IF NOT EXISTS converted_patient_id UUID REFERENCES patients(id) ON DELETE SET NULL,
//   ADD COLUMN IF NOT EXISTS contact_attempts     JSONB NOT NULL DEFAULT '[]';
//
// -- contact_attempts element shape:
// -- { "date": "ISO string", "method": "call|visit|whatsapp|other", "notes": "free text", "agent_id": "uuid" }

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/features/patients/patient_provider.dart';
import 'package:mediflow/models/user_role.dart';
import 'package:mediflow/models/visit_model.dart';

final drVisitsProvider = AsyncNotifierProvider<DrVisitsNotifier, List<DrVisit>>(
    DrVisitsNotifier.new);

final drVisitByIdProvider = Provider.family<DrVisit?, String>((ref, id) {
  final list = ref.watch(drVisitsProvider).valueOrNull;
  if (list == null) return null;
  for (final v in list) {
    if (v.id == id) return v;
  }
  return null;
});

class DrVisitsNotifier extends AsyncNotifier<List<DrVisit>> {
  @override
  Future<List<DrVisit>> build() async {
    return _fetchVisits();
  }

  Future<void> _runAndReload(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await action();
      return _fetchVisits();
    });
  }

  Future<List<DrVisit>> _fetchVisits() async {
    final supabase = ref.read(supabaseClientProvider);
    final userState = ref.watch(authNotifierProvider).value;
    final role = ref.watch(currentRoleProvider);

    try {
      var query = supabase.from('dr_visits').select('''
        *,
        patients:patients!dr_visits_patient_id_fkey(full_name)
      ''');

      if (role == UserRole.assistant && userState != null) {
        query = query.eq('assigned_agent_id', userState.session.user.id);
      }

      final response = await supabase.retry(() => query.order('visit_date', ascending: false));
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
        final agentResponse = await supabase.retry(() => supabase
            .from('doctors')
            .select('id, full_name')
            .inFilter('id', agentIds));

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
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }

  Future<void> createVisit({
    String? patientId,
    required String? assignedAgentId,
    required bool isExternal,
    String? extDoctorName,
    String? extDoctorSpecialization,
    String? extDoctorHospital,
    String? extDoctorPhone,
    String? leadPatientName,
    String? leadPatientPhone,
    String? leadPatientAddress,
    String? leadNotes,
    required String visitNotes,
    required String diagnosis,
    required DateTime? followupDate,
    required String followupNotes,
  }) async {
    await _runAndReload(() async {
      try {
        final supabase = ref.read(supabaseClientProvider);
        final user = supabase.auth.currentUser;
        if (user == null) return;

        final visitResponse = await supabase.retry(() => supabase
            .from('dr_visits')
            .insert({
              if (patientId != null) 'patient_id': patientId,
              'doctor_id': user.id,
              'assigned_agent_id': assignedAgentId,
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
              if (isExternal) 'lead_patient_name': leadPatientName,
              if (isExternal) 'lead_patient_phone': leadPatientPhone,
              if (isExternal) 'lead_patient_address': leadPatientAddress,
              if (isExternal) 'lead_notes': leadNotes,
            })
            .select()
            .single());

        if (!isExternal &&
            followupDate != null &&
            assignedAgentId != null &&
            patientId != null) {
          await supabase.retry(() => supabase.from('followup_tasks').insert({
                'patient_id': patientId,
                'dr_visit_id': visitResponse['id'],
                'assigned_to': assignedAgentId,
                'created_by': user.id,
                'due_date': followupDate.toIso8601String().split('T')[0],
                'notes': followupNotes,
              }));
        }
      } catch (e) {
        throw Exception(AppError.getMessage(e));
      }
    });
  }

  Future<void> updateStatus(String visitId, String status) async {
    await _runAndReload(() async {
      try {
        final supabase = ref.read(supabaseClientProvider);
        await supabase.retry(() => supabase.from('dr_visits').update({
              'status': status,
              'last_updated_at': DateTime.now().toIso8601String(),
            }).eq('id', visitId));
      } catch (e) {
        throw Exception(AppError.getMessage(e));
      }
    });
  }

  Future<void> updateFollowupStatus(
      String visitId, String followupStatus) async {
    await _runAndReload(() async {
      try {
        final supabase = ref.read(supabaseClientProvider);
        await supabase.retry(() => supabase.from('dr_visits').update({
              'followup_status': followupStatus,
              'last_updated_at': DateTime.now().toIso8601String(),
            }).eq('id', visitId));
      } catch (e) {
        throw Exception(AppError.getMessage(e));
      }
    });
  }

  Future<void> addContactAttempt(
      String visitId, Map<String, dynamic> attempt) async {
    await _runAndReload(() async {
      final supabase = ref.read(supabaseClientProvider);

      try {
        await supabase.retry(() => supabase.rpc('append_contact_attempt', params: {
          'visit_id': visitId,
          'attempt': attempt,
        }));
        await supabase.retry(() => supabase
            .from('dr_visits')
            .update({
              'lead_status': 'contacted',
              'last_updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', visitId)
            .eq('lead_status', 'new_lead'));
      } catch (_) {
        try {
          final row = await supabase.retry(() => supabase
              .from('dr_visits')
              .select('contact_attempts, lead_status')
              .eq('id', visitId)
              .maybeSingle());

          final current = ((row?['contact_attempts'] as List?) ?? const [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          current.add(attempt);

          final updates = <String, dynamic>{
            'contact_attempts': current,
            'last_updated_at': DateTime.now().toIso8601String(),
          };
          if ((row?['lead_status']?.toString() ?? 'new_lead') == 'new_lead') {
            updates['lead_status'] = 'contacted';
          }

          await supabase.retry(() => supabase.from('dr_visits').update(updates).eq('id', visitId));
        } catch (e) {
          throw Exception(AppError.getMessage(e));
        }
      }
    });
  }

  Future<void> updateLeadStatus(String visitId, String status) async {
    await _runAndReload(() async {
      try {
        final supabase = ref.read(supabaseClientProvider);
        await supabase.retry(() => supabase.from('dr_visits').update({
              'lead_status': status,
              'last_updated_at': DateTime.now().toIso8601String(),
            }).eq('id', visitId));
      } catch (e) {
        throw Exception(AppError.getMessage(e));
      }
    });
  }

  Future<void> convertLeadToPatient(String visitId, DrVisit visit) async {
    await _runAndReload(() async {
      try {
        final supabase = ref.read(supabaseClientProvider);
        final authState = ref.read(authNotifierProvider).valueOrNull;
        final currentUserId = authState?.session.user.id;
        final role = ref.read(currentRoleProvider);
        if (currentUserId == null) {
          throw Exception('Not authenticated.');
        }

        // Scope check before conversion: assistants can convert only their leads.
        var ownershipQuery = supabase.from('dr_visits').select(
            'id, assigned_agent_id, created_by_id, lead_status, lead_patient_name');
        ownershipQuery = ownershipQuery.eq('id', visitId);
        if (role == UserRole.assistant) {
          ownershipQuery = ownershipQuery.eq('assigned_agent_id', currentUserId);
        }
        final scopedLead =
            await supabase.retry(() => ownershipQuery.maybeSingle());
        if (scopedLead == null) {
          throw Exception('Lead not found in your scope.');
        }

        // Preferred secure path: server-side RPC enforces original mapping.
        try {
          await supabase.retry(() => supabase.rpc(
                'convert_lead_to_patient_secure',
                params: {'p_visit_id': visitId},
              ));
          return;
        } catch (_) {
          // TODO: Replace fallback with mandatory RPC once backend function is deployed.
        }

        // Fallback client path with strict scope checks.
        final patientId =
            await ref.read(patientProvider.notifier).registerPatient({
          'full_name': visit.leadPatientName?.trim() ?? '',
          'phone': visit.leadPatientPhone?.trim(),
          'address': visit.leadPatientAddress?.trim(),
          'referred_by': visit.extDoctorName?.trim(),
          'investigation_place': '',
          'investigation_status': <String, dynamic>{},
        });

        await supabase.retry(() => supabase.from('dr_visits').update({
              'lead_status': 'converted',
              'converted_patient_id': patientId,
              'patient_id': patientId,
              'last_updated_at': DateTime.now().toIso8601String(),
            }).eq('id', visitId));
      } catch (e) {
        throw Exception(AppError.getMessage(e));
      }
    });
  }
}
