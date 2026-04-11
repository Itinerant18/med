// lib/core/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/login_screen.dart';
import '../features/dashboard/main_screen.dart';
import '../features/auth/auth_provider.dart';
import 'realtime_service.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Show loading while waiting
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF5F0E8),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1A6B5A),
              ),
            ),
          );
        }

        final session = snapshot.data?.session;

        // If logged in → go to main app
        if (session != null) {
          final doctorName = ref.watch(authNotifierProvider).value?.doctorName ?? "Staff";
          
          // REQUIREMENT 6: Initialize RealtimeService
          WidgetsBinding.instance.addPostFrameCallback((_) {
            RealtimeService.instance.subscribeToPatientChanges(doctorName);
            RealtimeService.instance.subscribeToVisitChanges(doctorName);
          });

          return const MainScreen();
        }

        // If not logged in → go to login
        RealtimeService.instance.dispose();
        return const LoginScreen();
      },
    );
  }
}
