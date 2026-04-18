// lib/features/auth/auth_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthUserState?>(AuthNotifier.new);

final authStateProvider = StreamProvider<Session?>((ref) async* {
  final supabase = ref.watch(supabaseClientProvider);
  yield supabase.auth.currentSession;
  await for (final event in supabase.auth.onAuthStateChange) {
    yield event.session;
  }
});

// Single source of truth for current role
final currentRoleProvider = Provider<UserRole>((ref) {
  return ref.watch(authNotifierProvider).value?.role ?? UserRole.doctor;
});

class AuthUserState {
  const AuthUserState({
    required this.session,
    required this.doctorName,
    required this.specialization,
    required this.role,
    this.approvalStatus = 'pending',
    this.rejectionReason,
  });

  final Session session;
  final String? doctorName;
  final String? specialization;
  final UserRole role;
  final String approvalStatus;
  final String? rejectionReason;

  String get displayName => doctorName ?? 'User';
  String get displayRole => role.label;
  bool get isApproved => approvalStatus == 'approved';
  bool get isPending => approvalStatus == 'pending';
  bool get isRejected => approvalStatus == 'rejected';
}

class AuthNotifier extends AsyncNotifier<AuthUserState?> {
  SupabaseClient get _supabase => ref.read(supabaseClientProvider);
  bool _disposed = false;

  @override
  Future<AuthUserState?> build() async {
    _disposed = false;
    // Listen to auth state changes
    final sub = _supabase.auth.onAuthStateChange.listen((event) async {
      if (event.event == AuthChangeEvent.signedOut) {
        if (!_disposed) state = const AsyncData(null);
        return;
      }
      final nextState =
          await AsyncValue.guard(() => _resolveAuthUserState(event.session));
      if (!_disposed) state = nextState;
    });

    ref.onDispose(() {
      _disposed = true;
      sub.cancel();
    });
    return _resolveAuthUserState(_supabase.auth.currentSession);
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final session = response.session ?? _supabase.auth.currentSession;
      if (session == null) throw Exception('Sign-in succeeded but no session was created.');
      return _resolveAuthUserState(session);
    });
  }

  Future<void> signUp({
    required String fullName,
    required String specialization,
    required String email,
    required String password,
    UserRole? role,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final selectedRole = role ?? UserRole.doctor;

      final response = await _supabase.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'specialization': specialization.trim(),
          'role': selectedRole.name,
        },
      );

      final userId = response.user?.id;
      if (userId == null) {
        throw Exception('Registration failed. Please try again.');
      }

      // Upsert doctor record
      await _supabase.from('doctors').upsert({
        'id': userId,
        'full_name': fullName.trim(),
        'specialization': specialization.trim(),
        'email': email.trim(),
        'role': selectedRole.name,
        'approval_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      // If email confirmation is required, session will be null
      final session = response.session ?? _supabase.auth.currentSession;
      return _resolveAuthUserState(session);
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _supabase.auth.signOut();
      return null;
    });
  }

  Future<AuthUserState?> _resolveAuthUserState(Session? session) async {
    if (session == null) return null;

    final user = session.user;
    final metadata = user.userMetadata ?? const {};

    // Try to get profile from doctors table for most up-to-date info
    try {
      final profile = await _supabase
          .from('doctors')
          .select('full_name, specialization, role, approval_status, rejection_reason')
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null) {
        final roleString = profile['role'] as String? ??
            metadata['role'] as String? ?? 'doctor';
        return AuthUserState(
          session: session,
          doctorName: profile['full_name'] as String?,
          specialization: profile['specialization'] as String?,
          approvalStatus: profile['approval_status'] as String? ?? 'pending',
          rejectionReason: profile['rejection_reason'] as String?,
          role: UserRole.values.firstWhere(
            (e) => e.name == roleString,
            orElse: () => UserRole.doctor,
          ),
        );
      }
    } catch (_) {
      // Fall back to metadata if DB query fails
    }

    // Fallback to auth metadata
    final doctorName = metadata['full_name'] as String?;
    final specialization = metadata['specialization'] as String?;
    final roleString = metadata['role'] as String? ?? 'doctor';
    final role = UserRole.values.firstWhere(
      (e) => e.name == roleString,
      orElse: () => UserRole.doctor,
    );

    return AuthUserState(
      session: session,
      doctorName: doctorName,
      specialization: specialization,
      role: role,
      approvalStatus: 'pending',
    );
  }
}