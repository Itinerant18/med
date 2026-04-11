// lib/features/clinical/clinical_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/supabase_client.dart';

/// Provider for the patient search query string
final patientSearchQueryProvider = StateProvider<String>((ref) => '');

/// Provider that fetches patients matching the current search query
final filteredPatientsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(patientSearchQueryProvider);
  if (query.length < 2) return [];

  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('patients')
      .select('id, full_name, date_of_birth')
      .ilike('full_name', '%$query%')
      .limit(5);
  
  return List<Map<String, dynamic>>.from(response);
});

/// Notifier to handle the submission of visit records
class ClinicalNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> saveVisit(Map<String, dynamic> visitData) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('visits').upsert(visitData);
    });
  }
}

final clinicalNotifierProvider = AsyncNotifierProvider<ClinicalNotifier, void>(() {
  return ClinicalNotifier();
});
