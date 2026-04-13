// lib/core/router.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mediflow/core/auth_gate.dart';
import 'package:mediflow/features/dashboard/main_screen.dart';
import 'package:mediflow/features/patients/patient_form_screen.dart';
import 'package:mediflow/features/auth/register_screen.dart';
import 'package:mediflow/features/patients/patient_detail_screen.dart';
import 'package:mediflow/features/clinical/clinical_entry_screen.dart';
import 'package:mediflow/features/profile/doctor_profile_screen.dart';
import 'package:mediflow/features/profile/assistant_profile_screen.dart';
import 'package:mediflow/core/role_provider.dart';
import 'package:mediflow/features/profile/about_screen.dart';
import 'package:flutter/material.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const AuthGate(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const MainScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const _RoleBasedProfileRouter(),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/patients/new',
        builder: (context, state) => const PatientFormScreen(),
      ),
      GoRoute(
        path: '/patients/edit/:patientId',
        builder: (context, state) {
          final patientId = state.pathParameters['patientId'];
          return PatientFormScreen(patientId: patientId);
        },
      ),
      GoRoute(
        path: '/patients/:patientId/detail',
        builder: (context, state) {
          final patientId = state.pathParameters['patientId']!;
          return PatientDetailScreen(patientId: patientId);
        },
      ),
      GoRoute(
        path: '/clinical/new',
        builder: (context, state) {
          // Can receive String (id) or Map (id + name)
          final extra = state.extra;
          String? id;
          if (extra is String) id = extra;
          if (extra is Map) id = extra['patientId'];
          return ClinicalEntryScreen(patientId: id);
        },
      ),
    ],
  );
});

class _RoleBasedProfileRouter extends ConsumerWidget {
  const _RoleBasedProfileRouter();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    return isAdmin
        ? const DoctorProfileScreen()
        : const AssistantProfileScreen();
  }
}
