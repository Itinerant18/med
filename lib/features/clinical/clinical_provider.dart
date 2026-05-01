// lib/features/clinical/clinical_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/models/user_role.dart';

final patientSearchQueryProvider = StateProvider<String>((ref) => '');

final clinicalPatientSearchProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(patientSearchQueryProvider);

  final searchQueryNotifier = ref.read(patientSearchQueryProvider.notifier);
  ref.onDispose(() {
    searchQueryNotifier.state = '';
  });

  if (query.trim().length < 2) return [];

  final supabase = ref.watch(supabaseClientProvider);
  final userState = ref.watch(authNotifierProvider).value;

  try {
    var dbQuery = supabase
        .from('patients')
        .select('id, full_name, date_of_birth')
        .ilike('full_name', '%${query.trim()}%');

    // Agents only see their own patients. Doctors and head doctors see all.
    if (userState != null && userState.role == UserRole.assistant) {
      dbQuery = dbQuery.eq('created_by_id', userState.session.user.id);
    }

    final response = await supabase.retry(() => dbQuery.limit(8));
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    throw Exception(AppError.getMessage(e));
  }
});

class ClinicalNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> saveVisit(Map<String, dynamic> visitData) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final supabase = ref.read(supabaseClientProvider);
        final userState = ref.read(authNotifierProvider).value;

        if (userState == null) throw Exception('Not authenticated');

        // Clean null/empty values
        final cleanedData = Map<String, dynamic>.fromEntries(
          visitData.entries.where((e) => e.value != null),
        );

        final finalVisitData = {
          ...cleanedData,
          'created_by_id': userState.session.user.id,
          'last_updated_by_id': userState.session.user.id,
          'last_updated_by': userState.doctorName ?? 'Staff',
          'last_updated_at': DateTime.now().toIso8601String(),
        };

        await supabase.retry(() => supabase.from('visits').insert(finalVisitData));
      } catch (e) {
        throw Exception(AppError.getMessage(e));
      }
    });
  }
}

final clinicalNotifierProvider =
    AsyncNotifierProvider<ClinicalNotifier, void>(ClinicalNotifier.new);
