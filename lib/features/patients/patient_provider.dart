// lib/features/patients/patient_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/features/auth/auth_provider.dart';

final patientProvider = Provider((ref) => PatientService(ref));

/// Provider to fetch a single patient by ID (Future)
final patientDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  final supabase = ref.read(supabaseClientProvider);
  final response = await supabase.from('patients').select().eq('id', id).maybeSingle();
  return response;
});

class PatientService {
  final Ref _ref;
  PatientService(this._ref);

  Future<void> registerPatient(Map<String, dynamic> patientData) async {
    final supabase = _ref.read(supabaseClientProvider);
    final doctorName = _ref.read(authNotifierProvider).value?.doctorName ?? "Staff";

    final finalData = {
      ...patientData,
      'last_updated_by': doctorName,
      'last_updated_at': DateTime.now().toIso8601String(),
      'service_status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    };

    await supabase.from('patients').insert(finalData);
  }

  Future<void> updatePatient(String id, Map<String, dynamic> patientData) async {
    final supabase = _ref.read(supabaseClientProvider);
    final doctorName = _ref.read(authNotifierProvider).value?.doctorName ?? "Staff";

    final finalData = {
      ...patientData,
      'last_updated_by': doctorName,
      'last_updated_at': DateTime.now().toIso8601String(),
    };

    await supabase.from('patients').update(finalData).eq('id', id);
  }
}
