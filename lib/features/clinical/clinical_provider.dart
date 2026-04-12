// lib/features/clinical/clinical_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/models/user_role.dart';

final patientSearchQueryProvider = StateProvider<String>((ref) => '');

final clinicalPatientSearchProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(patientSearchQueryProvider);
  if (query.trim().length < 2) return [];
  final supabase = ref.watch(supabaseClientProvider);
  final userState = ref.watch(authNotifierProvider).value;

  var dbQuery = supabase
      .from('patients')
      .select('id, full_name, date_of_birth')
      .ilike('full_name', '%$query%');

  if (userState != null && userState.role == UserRole.assistant) {
    dbQuery = dbQuery.eq('created_by_id', userState.session.user.id);
  }

  final response = await dbQuery.limit(8);
  return List<Map<String, dynamic>>.from(response);
});

class ClinicalNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> saveVisit(Map<String, dynamic> visitData) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final supabase = ref.read(supabaseClientProvider);
      final userState = ref.read(authNotifierProvider).value;
      
      final finalVisitData = {
        ...visitData,
        'created_by_id': userState?.session.user.id,
        'last_updated_by_id': userState?.session.user.id,
      };
      
      await supabase.from('visits').insert(finalVisitData);
    });
  }
}

final clinicalNotifierProvider =
    AsyncNotifierProvider<ClinicalNotifier, void>(ClinicalNotifier.new);
