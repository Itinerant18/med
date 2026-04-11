// lib/features/clinical/clinical_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/supabase_client.dart';

final patientSearchQueryProvider = StateProvider<String>((ref) => '');

final clinicalPatientSearchProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(patientSearchQueryProvider);
  if (query.trim().length < 2) return [];
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('patients')
      .select('id, full_name, date_of_birth')
      .ilike('full_name', '%$query%')
      .limit(8);
  return List<Map<String, dynamic>>.from(response);
});

class ClinicalNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> saveVisit(Map<String, dynamic> visitData) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('visits').insert(visitData);
    });
  }
}

final clinicalNotifierProvider =
    AsyncNotifierProvider<ClinicalNotifier, void>(ClinicalNotifier.new);
