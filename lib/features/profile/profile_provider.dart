// lib/features/profile/profile_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediflow/core/cache_service.dart';
import 'package:mediflow/core/supabase_client.dart';

class ProfileNotifier extends AsyncNotifier<Map<String, dynamic>> {
  @override
  FutureOr<Map<String, dynamic>> build() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final supabase = ref.read(supabaseClientProvider);

    try {
      // Use maybeSingle() instead of single() to avoid throwing
      // when no doctor row exists yet.
      final existing = await supabase
          .from('doctors')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existing != null) {
        return Map<String, dynamic>.from(existing);
      }
    } catch (e, st) {
      // Log so we can see the real cause instead of the generic fallback.
      debugPrint('[profile] SELECT failed: $e\n$st');
      rethrow;
    }

    // Profile row missing — synthesize one from auth metadata so the UI still
    // renders. Attempt to persist it best-effort; never fail the screen just
    // because the INSERT raced or RLS pushed back.
    final metadata = user.userMetadata ?? const {};
    final fallback = <String, dynamic>{
      'id': user.id,
      'full_name': metadata['full_name'] ?? user.email ?? 'User',
      'specialization': metadata['specialization'] ?? '',
      'email': user.email ?? '',
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      await supabase.from('doctors').upsert(fallback, onConflict: 'id');
    } catch (e, st) {
      debugPrint('[profile] fallback upsert failed (non-fatal): $e\n$st');
    }
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
          .maybeSingle();
      if (updated == null) throw Exception('Profile row missing after update.');
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
  const empty = <String, int>{'patients': 0, 'visits': 0, 'days': 0};

  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return empty;

  final cacheKey = 'profile_stats_${user.id}';

  final profileAsync = ref.watch(profileNotifierProvider);
  final profileData = profileAsync.valueOrNull;
  if (profileAsync.isLoading || profileData == null) return empty;

  final doctorName = (profileData['full_name'] ?? '').toString();
  if (doctorName.isEmpty) return empty;

  final supabase = ref.watch(supabaseClientProvider);

  try {
    final results = await Future.wait<List<dynamic>>([
      supabase
          .from('visits')
          .select('id')
          .eq('doctor_id', user.id)
          .then((value) => value as List<dynamic>)
          .catchError((_) => <dynamic>[]),
      supabase
          .from('patients')
          .select('id')
          .eq('last_updated_by', doctorName)
          .then((value) => value as List<dynamic>)
          .catchError((_) => <dynamic>[]),
    ]);
    final visitsRes = results[0];
    final patientsRes = results[1];

    final createdAtRaw = profileData['created_at'];
    final createdAt = createdAtRaw != null
        ? DateTime.tryParse(createdAtRaw.toString()) ?? DateTime.now()
        : DateTime.now();
    final daysActive = DateTime.now().difference(createdAt).inDays + 1;

    final freshStats = {
      'patients': patientsRes.length,
      'visits': visitsRes.length,
      'days': daysActive,
    };

    CacheService.instance
        .putRaw(cacheKey, freshStats, ttl: const Duration(minutes: 30))
        .ignore();
    return freshStats;
  } catch (_) {
    final cached =
        CacheService.instance.getRaw(cacheKey) as Map<String, dynamic>?;
    if (cached != null) {
      return {
        'patients': (cached['patients'] as num?)?.toInt() ?? 0,
        'visits': (cached['visits'] as num?)?.toInt() ?? 0,
        'days': (cached['days'] as num?)?.toInt() ?? 0,
      };
    }
    return empty;
  }
});
