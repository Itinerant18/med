// lib/core/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediflow/core/theme.dart';
import '../features/auth/login_screen.dart';
import '../features/dashboard/main_screen.dart';
import '../features/auth/auth_provider.dart';
import '../features/approval/approval_provider.dart';
import '../features/approval/awaiting_approval_screen.dart';
import '../features/approval/rejected_screen.dart';
import 'realtime_service.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Show loading while waiting for initial connection
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        final session = snapshot.data?.session;

        if (session != null) {
          // Get doctor name safely
          final authState = ref.watch(authNotifierProvider);

          // Show loading while auth resolves
          if (authState.isLoading) {
            return const _SplashScreen();
          }

          final userState = authState.value;
          if (userState == null) return const LoginScreen();

          // Handle approval status
          if (userState.isPending) {
            return const AwaitingApprovalScreen();
          }
          if (userState.isRejected) {
            return RejectedScreen(reason: userState.rejectionReason);
          }

          final doctorName = userState.doctorName ?? 'Staff';

          // Initialize real-time subscriptions after frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              RealtimeService.instance
                  .subscribeToPatientChanges(doctorName, ref);
              if (userState.isHeadDoctor) {
                ref
                    .read(pendingApprovalsProvider.notifier)
                    .listenForNewRegistrations();
              }
            } catch (e) {
              debugPrint('RealtimeService error: $e');
            }
          });

          return const MainScreen();
        }

        // Not logged in
        RealtimeService.instance.dispose();
        return const LoginScreen();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AnimatedLogo(),
            SizedBox(height: 24),
            CircularProgressIndicator(
              color: AppTheme.primaryTeal,
              strokeWidth: 2.5,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedLogo extends StatefulWidget {
  const _AnimatedLogo();

  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppTheme.primaryTeal,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryTeal.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
          Icons.local_hospital_rounded,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }
}
