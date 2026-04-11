import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// TODO: Manage authentication state and auth-related business logic.

final authNotifierProvider =
		AsyncNotifierProvider<AuthNotifier, AuthUserState?>(AuthNotifier.new);

final authStateProvider = StreamProvider<Session?>((ref) async* {
	final supabase = ref.watch(supabaseClientProvider);
	yield supabase.auth.currentSession;

	await for (final event in supabase.auth.onAuthStateChange) {
		yield event.session;
	}
});

class AuthUserState {
	const AuthUserState({
		required this.session,
		required this.doctorName,
		required this.specialization,
	});

	final Session session;
	final String? doctorName;
	final String? specialization;
}

class AuthNotifier extends AsyncNotifier<AuthUserState?> {
	SupabaseClient get _supabase => ref.read(supabaseClientProvider);

	@override
	Future<AuthUserState?> build() async {
		final sub = _supabase.auth.onAuthStateChange.listen((event) async {
			final nextState =
					await AsyncValue.guard(() => _resolveAuthUserState(event.session));
			state = nextState;
		});

		ref.onDispose(sub.cancel);
		return _resolveAuthUserState(_supabase.auth.currentSession);
	}

	Future<void> signIn({required String email, required String password}) async {
		state = const AsyncLoading();
		state = await AsyncValue.guard(() async {
			final response = await _supabase.auth.signInWithPassword(
				email: email,
				password: password,
			);
			final session = response.session ?? _supabase.auth.currentSession;
			return _resolveAuthUserState(session);
		});
	}

	Future<void> signUp({
		required String fullName,
		required String specialization,
		required String email,
		required String password,
	}) async {
		state = const AsyncLoading();
		state = await AsyncValue.guard(() async {
			final response = await _supabase.auth.signUp(
				email: email,
				password: password,
				data: {
					'full_name': fullName,
					'specialization': specialization,
				},
			);

			final userId = response.user?.id;
			if (userId != null) {
				await _supabase.from('doctors').upsert({
					'id': userId,
					'full_name': fullName,
					'specialization': specialization,
					'email': email,
				}, onConflict: 'id');
			}

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
		if (session == null) {
			return null;
		}

		final user = session.user;
		final metadata = user.userMetadata ?? const {};
		final doctorName = metadata['full_name'] as String?;
		final specialization = metadata['specialization'] as String?;

		return AuthUserState(
			session: session,
			doctorName: doctorName,
			specialization: specialization,
		);
	}
}
