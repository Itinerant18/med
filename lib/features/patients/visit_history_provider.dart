// lib/features/patients/visit_history_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/supabase_client.dart';

final visitHistoryProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, patientId) async {
  final supabase = ref.read(supabaseClientProvider);
  final response = await supabase
      .from('visits')
      .select()
      .eq('patient_id', patientId)
      .order('visit_date', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});
