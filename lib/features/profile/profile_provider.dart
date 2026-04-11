import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediflow/core/supabase_client.dart';

class ProfileNotifier extends AsyncNotifier<Map<String, dynamic>> {
  @override
  FutureOr<Map<String, dynamic>> build() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final supabase = ref.watch(supabaseClientProvider);
    final response = await supabase
        .from('doctors')
        .select()
        .eq('id', user.id)
        .single();
    
    return Map<String, dynamic>.from(response);
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = Supabase.instance.client.auth.currentUser;
      final supabase = ref.read(supabaseClientProvider);

      await supabase.from('doctors').update({
        ...data,
        'profile_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user!.id);

      // Refresh data
      final updated = await supabase
          .from('doctors')
          .select()
          .eq('id', user.id)
          .single();
      return Map<String, dynamic>.from(updated);
    });
  }
}

final profileNotifierProvider = AsyncNotifierProvider<ProfileNotifier, Map<String, dynamic>>(() {
  return ProfileNotifier();
});

/// Provider for profile statistics (Patients Added, Visits Logged, Days Active)
final profileStatsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return {'patients': 0, 'visits': 0, 'days': 0};

  final supabase = ref.watch(supabaseClientProvider);
  final profile = ref.watch(profileNotifierProvider).valueOrNull;
  final doctorName = profile?['full_name'] ?? '';

  // 1. Patients Added by this doctor
  final patientsRes = await supabase
      .from('patients')
      .select('id')
      .eq('last_updated_by', doctorName);

  // 2. Visits logged by this doctor
  final visitsRes = await supabase
      .from('visits')
      .select('id')
      .eq('doctor_id', user.id);

  // 3. Days Active
  final createdAt = DateTime.parse(profile?['created_at'] ?? DateTime.now().toIso8601String());
  final daysActive = DateTime.now().difference(createdAt).inDays + 1;

  return {
    'patients': patientsRes.length,
    'visits': visitsRes.length,
    'days': daysActive,
  };
});
