// lib/features/auth/auth_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/fcm_service.dart';
import 'package:mediflow/core/google_auth_config.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/models/user_role.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String normalizePhoneNumber(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return '';

  if (trimmed.startsWith('+')) {
    final digits = trimmed.substring(1).replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? '' : '+$digits';
  }

  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.length == 10) return '+91$digits';
  return '+$digits';
}

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
  return ref.watch(authNotifierProvider).value?.role ?? UserRole.assistant;
});

class AuthUserState {
  const AuthUserState({
    required this.session,
    required this.doctorName,
    required this.specialization,
    required this.role,
    required this.linkedProviders,
    this.approvalStatus = 'pending',
    this.rejectionReason,
    this.phone,
    this.phoneVerified = false,
  });

  final Session session;
  final String? doctorName;
  final String? specialization;
  final UserRole role;
  final Set<String> linkedProviders;
  final String approvalStatus;
  final String? rejectionReason;
  final String? phone;
  final bool phoneVerified;

  String get displayName => doctorName ?? 'User';
  String get displayRole => role.label;
  bool get isHeadDoctor => role == UserRole.headDoctor;
  bool get isApproved => approvalStatus == 'approved';
  bool get isPending => approvalStatus == 'pending';
  bool get isRejected => approvalStatus == 'rejected';
  bool get hasPasswordIdentity => linkedProviders.contains('email');
  bool get hasGoogleIdentity => linkedProviders.contains('google');
}

class AuthNotifier extends AsyncNotifier<AuthUserState?> {
  SupabaseClient get _supabase => ref.read(supabaseClientProvider);
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    serverClientId:
        GoogleAuthConfig.hasWebClientId ? GoogleAuthConfig.webClientId : null,
    clientId: switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS =>
        GoogleAuthConfig.hasIosClientId ? GoogleAuthConfig.iosClientId : null,
      _ => null,
    },
  );
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

      // Sync FCM token whenever the user signs in
      if (event.event == AuthChangeEvent.signedIn) {
        _syncFcmToken();
      }
    });

    ref.onDispose(() {
      _disposed = true;
      sub.cancel();
    });

    final result = await _resolveAuthUserState(_supabase.auth.currentSession);

    // Sync FCM token on initial load if already signed in
    if (_supabase.auth.currentSession != null) {
      _syncFcmToken();
    }

    return result;
  }

  void _syncFcmToken() {
    Future.microtask(() => FcmService.instance.syncToken());
  }

  Future<Map<String, dynamic>?> _lookupAccountByPhone(String phone) async {
    final response = await _supabase
        .rpc('lookup_account_by_phone', params: {'p_phone': phone})
        .maybeSingle();
    return response;
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
      if (session == null) {
        throw Exception('Sign-in succeeded but no session was created.');
      }
      // Sync FCM token after sign in
      _syncFcmToken();
      return _resolveAuthUserState(session);
    });
  }

  Future<void> signInWithPhone({
    required String phone,
    required String password,
  }) async {
    final normalizedPhone = normalizePhoneNumber(phone);
    if (normalizedPhone.isEmpty) {
      throw Exception('Enter a valid mobile number.');
    }

    final doctor = await _lookupAccountByPhone(normalizedPhone);

    final email = doctor?['email'] as String?;
    if (email == null || email.trim().isEmpty) {
      throw Exception('No password account was found for this mobile number.');
    }

    await signIn(email: email, password: password);
  }

  Future<void> signUp({
    required String fullName,
    required String specialization,
    required String email,
    required String password,
    required String phone, // ← NEW: phone number
    UserRole? role,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final selectedRole = role ?? UserRole.doctor;
      final normalizedPhone = normalizePhoneNumber(phone);

      if (normalizedPhone.isEmpty) {
        throw Exception('Enter a valid mobile number.');
      }

      final response = await _supabase.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'specialization': specialization.trim(),
          'role': selectedRole == UserRole.headDoctor
              ? 'doctor'
              : selectedRole.name,
        },
      );

      final userId = response.user?.id;
      if (userId == null) {
        throw Exception('Registration failed. Please try again.');
      }

      // Upsert doctor record including phone + phone_verified flag
      await _supabase.from('doctors').upsert({
        'id': userId,
        'full_name': fullName.trim(),
        'specialization': specialization.trim(),
        'email': email.trim(),
        'phone': normalizedPhone,
        'phone_verified': true, // ← Phone was verified via Firebase OTP
        'role':
            selectedRole == UserRole.headDoctor ? 'doctor' : selectedRole.databaseValue,
        'approval_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      final session = response.session ?? _supabase.auth.currentSession;
      return _resolveAuthUserState(session);
    });
  }

  Future<void> signInWithGoogle({
    required String phone,
    required bool requireExistingAccount,
    String? fullName,
    String? specialization,
    UserRole? role,
    bool phoneVerified = false,
  }) async {
    final normalizedPhone = normalizePhoneNumber(phone);
    if (normalizedPhone.isEmpty) {
      throw Exception('Enter a valid mobile number first.');
    }

    final selectedRole = role ?? UserRole.doctor;
    final doctorByPhone = await _lookupAccountByPhone(normalizedPhone);

    if (requireExistingAccount && doctorByPhone == null) {
      throw Exception(
        'No account was found for this mobile number. Register first.',
      );
    }

    if (!requireExistingAccount && doctorByPhone != null) {
      throw Exception(
        'This mobile number is already registered. Please sign in instead.',
      );
    }

    if (!requireExistingAccount && !phoneVerified) {
      throw Exception(
          'Verify your mobile number before continuing with Google.');
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null || accessToken == null) {
        throw Exception(_missingGoogleTokenMessage());
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final session = response.session ?? _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('Google sign-in succeeded but no session was created.');
      }

      if (requireExistingAccount) {
        final profile = await _supabase
            .from('doctors')
            .select('phone')
            .eq('id', session.user.id)
            .maybeSingle();

        final profilePhone = profile?['phone'] as String?;
        if (profilePhone != normalizedPhone) {
          await _supabase.auth.signOut();
          await _googleSignIn.signOut();
          throw Exception(
            'This Google sign-in is not linked to that account yet. Sign in with your password once, then link Google from your profile.',
          );
        }

        _syncFcmToken();
        return _resolveAuthUserState(session);
      }

      await _supabase.from('doctors').upsert({
        'id': session.user.id,
        'full_name': (fullName ?? googleUser.displayName ?? '').trim(),
        'specialization': (specialization ?? '').trim(),
        'email': session.user.email?.trim() ?? googleUser.email.trim(),
        'phone': normalizedPhone,
        'phone_verified': true,
        'role':
            selectedRole == UserRole.headDoctor ? 'doctor' : selectedRole.databaseValue,
        'approval_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      _syncFcmToken();
      return _resolveAuthUserState(session);
    });
  }

  Future<void> linkGoogleIdentity() async {
    final currentSession = _supabase.auth.currentSession;
    if (currentSession == null) {
      throw Exception('Sign in first to link Google.');
    }

    final currentState = state.valueOrNull;
    if (currentState?.hasGoogleIdentity == true) {
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _googleSignIn.signOut();

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google linking was cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null || accessToken == null) {
        throw Exception(_missingGoogleTokenMessage());
      }

      final response = await _supabase.auth.linkIdentityWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final session = response.session ?? _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('Google was linked but the session could not be refreshed.');
      }

      return _resolveAuthUserState(session);
    });
  }

  Future<void> signOut() async {
    // Clear FCM token before signing out
    await FcmService.instance.clearToken();
    await _googleSignIn.signOut();

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
    final linkedProviders = await _getLinkedProviders(user);

    try {
      final profile = await _supabase
          .from('doctors')
          .select(
              'full_name, specialization, role, approval_status, rejection_reason, phone, phone_verified')
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null) {
        return AuthUserState(
          session: session,
          doctorName: profile['full_name'] as String?,
          specialization: profile['specialization'] as String?,
          approvalStatus: profile['approval_status'] as String? ?? 'pending',
          rejectionReason: profile['rejection_reason'] as String?,
          role: UserRole.fromString(profile['role'] as String?),
          linkedProviders: linkedProviders,
          phone: profile['phone'] as String?,
          phoneVerified: profile['phone_verified'] as bool? ?? false,
        );
      }
    } catch (_) {
      // Fall back to metadata if DB query fails
    }

    // Fallback to auth metadata
    return AuthUserState(
      session: session,
      doctorName: metadata['full_name'] as String?,
      specialization: metadata['specialization'] as String?,
      role: UserRole.fromString(metadata['role'] as String?),
      linkedProviders: linkedProviders,
      approvalStatus: 'pending',
    );
  }

  Future<Set<String>> _getLinkedProviders(User user) async {
    try {
      final identities = await _supabase.auth.getUserIdentities();
      return identities.map((identity) => identity.provider).toSet();
    } catch (_) {
      final identities = user.identities ?? const <UserIdentity>[];
      return identities.map((identity) => identity.provider).toSet();
    }
  }

  String _missingGoogleTokenMessage() {
    if (!GoogleAuthConfig.hasWebClientId) {
      return 'Google sign-in is missing GOOGLE_WEB_CLIENT_ID. Add your Google Web OAuth client ID to both Supabase and the app.';
    }

    final isApplePlatform = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    if (isApplePlatform && !GoogleAuthConfig.hasIosClientId) {
      return 'Google sign-in is missing GOOGLE_IOS_CLIENT_ID for this Apple build.';
    }

    return 'Google sign-in did not return valid tokens.';
  }
}
