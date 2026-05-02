// lib/core/router.dart
import 'package:flutter/material.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mediflow/core/auth_gate.dart';
import 'package:mediflow/core/navigation_service.dart';
import 'package:mediflow/core/role_provider.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/agent_visits/agent_outside_visit_form.dart';
import 'package:mediflow/features/agent_visits/agent_outside_visit_list_screen.dart';
import 'package:mediflow/features/analytics/analytics_screen.dart';
import 'package:mediflow/features/approval/pending_approvals_screen.dart';
import 'package:mediflow/features/audit/audit_logs_screen.dart';
import 'package:mediflow/features/auth/register_screen.dart';
import 'package:mediflow/features/clinical/clinical_entry_screen.dart';
import 'package:mediflow/features/dashboard/performance_dashboard_screen.dart';
import 'package:mediflow/features/dr_visits/dr_visit_detail_screen.dart';
import 'package:mediflow/features/followups/doctor_followups_screen.dart';
import 'package:mediflow/features/followups/followup_review_screen.dart';
import 'package:mediflow/features/dr_visits/dr_visit_form.dart';
import 'package:mediflow/features/patients/patient_detail_screen.dart';
import 'package:mediflow/features/patients/patient_form_screen.dart';
import 'package:mediflow/features/profile/about_screen.dart';
import 'package:mediflow/features/profile/assistant_profile_screen.dart';
import 'package:mediflow/features/profile/doctor_profile_screen.dart';
import 'package:mediflow/features/profile/notification_preferences_screen.dart';
import 'package:mediflow/features/staff/staff_management_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: false,
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(AppIcons.error_outline_rounded,
                size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            const Text('Page not found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(state.uri.toString(),
                style:
                    const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
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
        path: '/profile',
        builder: (context, state) => const _RoleBasedProfileRouter(),
      ),
      GoRoute(
        path: '/notification-preferences',
        builder: (context, state) => const NotificationPreferencesScreen(),
      ),
      GoRoute(
        path: '/pending-approvals',
        redirect: (context, state) {
          // Head-doctor only. Bounce others to root.
          final container = ProviderScope.containerOf(context);
          final isHead = container.read(isHeadDoctorProvider);
          return isHead ? null : '/';
        },
        builder: (context, state) => const PendingApprovalsScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/analytics',
        redirect: (context, state) {
          // Analytics is admin-only. Bounce non-admins back to root.
          final container = ProviderScope.containerOf(context);
          final isAdmin = container.read(isAdminProvider);
          return isAdmin ? null : '/';
        },
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/staff',
        builder: (context, state) => const StaffManagementScreen(),
      ),
      GoRoute(
        path: '/audit-logs',
        builder: (context, state) => const AuditLogsScreen(),
      ),
      GoRoute(
        path: '/performance',
        builder: (context, state) => const PerformanceDashboardScreen(),
      ),
      GoRoute(
        path: '/patients/new',
        builder: (context, state) => const PatientFormScreen(),
      ),
      GoRoute(
        path: '/patients/edit/:patientId',
        builder: (context, state) {
          final patientId = state.pathParameters['patientId'];
          if (patientId == null || patientId.isEmpty) {
            return const PatientFormScreen();
          }
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
          final extra = state.extra;
          String? id;
          String? name;
          if (extra is String) {
            id = extra;
          } else if (extra is Map) {
            id = extra['patientId'] as String?;
            name = extra['patientName'] as String?;
          }
          return ClinicalEntryScreen(patientId: id, patientName: name);
        },
      ),
      GoRoute(
        path: '/dr-visits/new',
        builder: (context, state) => const DrVisitForm(),
      ),
      GoRoute(
        path: '/dr-visits/:visitId',
        builder: (context, state) {
          final visitId = state.pathParameters['visitId']!;
          return DrVisitDetailScreen(visitId: visitId);
        },
      ),
      GoRoute(
        path: '/agent-visits',
        builder: (context, state) => const AgentOutsideVisitListScreen(),
      ),
      GoRoute(
        path: '/agent-visits/new',
        builder: (context, state) {
          final extra = state.extra;
          String? readString(String key) {
            if (extra is! Map) return null;
            final v = extra[key];
            if (v == null) return null;
            final s = v.toString();
            return s.isEmpty ? null : s;
          }

          return AgentOutsideVisitForm(
            followupTaskId: readString('followupTaskId'),
            preselectedPatientId: readString('patientId'),
            preselectedPatientName: readString('patientName'),
            prefillExtDoctorName: readString('prefillExtDoctorName'),
            prefillExtDoctorHospital: readString('prefillExtDoctorHospital'),
            prefillExtDoctorSpecialization:
                readString('prefillExtDoctorSpecialization'),
            prefillExtDoctorPhone: readString('prefillExtDoctorPhone'),
            prefillVisitInstructions: readString('prefillVisitInstructions'),
          );
        },
      ),
      GoRoute(
        path: '/agent-visits/edit/:visitId',
        builder: (context, state) {
          final visitId = state.pathParameters['visitId'];
          if (visitId == null || visitId.isEmpty) {
            return const AgentOutsideVisitForm();
          }
          return AgentOutsideVisitForm(visitId: visitId);
        },
      ),
      GoRoute(
        path: '/followups/doctor',
        redirect: (context, state) {
          // Doctor / head-doctor only.
          final container = ProviderScope.containerOf(context);
          return container.read(isAdminProvider) ? null : '/';
        },
        builder: (context, state) => const DoctorFollowupsScreen(),
      ),
      GoRoute(
        path: '/followups/review/:taskId',
        redirect: (context, state) {
          final container = ProviderScope.containerOf(context);
          return container.read(isAdminProvider) ? null : '/';
        },
        builder: (context, state) {
          final taskId = state.pathParameters['taskId'] ?? '';
          return FollowupReviewScreen(taskId: taskId);
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
