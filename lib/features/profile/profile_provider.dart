// lib/features/profile/profile_provider.dart
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

    // Use maybeSingle() instead of single() to avoid throwing
    // when no doctor row exists yet
    final existing = await supabase
        .from('doctors')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (existing != null) {
      return Map<String, dynamic>.from(existing);
    }

    // Doctor row missing — create it from auth metadata
    final metadata = user.userMetadata ?? {};
    final fallback = {
      'id': user.id,
      'full_name': metadata['full_name'] ?? user.email ?? 'Doctor',
      'specialization': metadata['specialization'] ?? '',
      'email': user.email ?? '',
      'created_at': DateTime.now().toIso8601String(),
    };

    await supabase.from('doctors').upsert(fallback, onConflict: 'id');
    return fallback;
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');
      final supabase = ref.read(supabaseClientProvider);

      await supabase.from('doctors').update({
        ...data,
        'profile_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      final updated = await supabase
          .from('doctors')
          .select()
          .eq('id', user.id)
          .single();
      return Map<String, dynamic>.from(updated);
    });
  }
}

final profileNotifierProvider =
    AsyncNotifierProvider<ProfileNotifier, Map<String, dynamic>>(
  ProfileNotifier.new,
);

final profileStatsProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return {'patients': 0, 'visits': 0, 'days': 0};

  final supabase = ref.watch(supabaseClientProvider);

  // Use doctor_id (UUID) for visits instead of name string
  // Use created_by_id for patients if available, else fallback to name
  final visitsRes = await supabase
      .from('visits')
      .select('id')
      .eq('doctor_id', user.id);

  // Get doctor name for patient count
  final profileData = ref.watch(profileNotifierProvider).valueOrNull;
  final doctorName = profileData?['full_name'] ?? '';

  final patientsRes = doctorName.isNotEmpty
      ? await supabase
          .from('patients')
          .select('id')
          .eq('last_updated_by', doctorName)
      : <dynamic>[];

  final createdAtRaw = profileData?['created_at'];
  final createdAt = createdAtRaw != null
      ? DateTime.tryParse(createdAtRaw.toString()) ?? DateTime.now()
      : DateTime.now();
  final daysActive = DateTime.now().difference(createdAt).inDays + 1;

  return {
    'patients': patientsRes.length,
    'visits': visitsRes.length,
    'days': daysActive,
  };
});
