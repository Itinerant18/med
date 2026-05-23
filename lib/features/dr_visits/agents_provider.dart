import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/models/doctor_model.dart';
import 'package:mediflow/models/user_role.dart';

// Returns all approved agents (assistants) for assignment in dr_visits.
final agentsProvider = FutureProvider<List<DoctorModel>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  try {
    final response = await supabase.retry(() => supabase
        .from('doctors')
        .select('id, full_name, specialization, email, role, approval_status')
        // Use the enum's databaseValue so the role string here can never drift
        // out of sync with how the rest of the app writes it.
        .eq('role', UserRole.assistant.databaseValue)
        .eq('approval_status', 'approved'));

    return (response as List)
        .map((json) =>
            DoctorModel.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  } catch (e) {
    throw Exception(AppError.getMessage(e));
  }
});

// Returns all approved doctors (non-agent) for display/management by head doctor.
final doctorsProvider = FutureProvider<List<DoctorModel>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  try {
    final response = await supabase.retry(() => supabase
        .from('doctors')
        .select('id, full_name, specialization, email, role, approval_status')
        .inFilter('role', [
      UserRole.headDoctor.databaseValue,
      UserRole.doctor.databaseValue,
    ]).eq('approval_status', 'approved'));

    return (response as List)
        .map((json) =>
            DoctorModel.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  } catch (e) {
    throw Exception(AppError.getMessage(e));
  }
});

// A unified provider that maps user ID to DoctorModel for rapid UI lookup.
final staffMapProvider = FutureProvider<Map<String, DoctorModel>>((ref) async {
  final agents = await ref.watch(agentsProvider.future);
  final doctors = await ref.watch(doctorsProvider.future);
  final map = <String, DoctorModel>{};
  for (final a in agents) {
    map[a.id] = a;
  }
  for (final d in doctors) {
    map[d.id] = d;
  }
  return map;
});

