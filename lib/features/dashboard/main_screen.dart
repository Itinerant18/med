// lib/features/dashboard/main_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mediflow/core/notification_provider.dart';
import 'package:mediflow/core/role_provider.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/features/clinical/clinical_entry_screen.dart';
import 'package:mediflow/features/dashboard/dashboard_screen.dart';
import 'package:mediflow/features/dashboard/notification_sheet.dart';
import 'package:mediflow/features/dr_visits/dr_visit_screen.dart';
import 'package:mediflow/features/followups/my_followups_screen.dart';
import 'package:mediflow/features/patients/patient_list_screen.dart';
import 'package:mediflow/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red, size: 20),
            SizedBox(width: 10),
            Text('Sign Out', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text('Are you sure you want to sign out of MediFlow?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    try {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (mounted) context.go('/');
    } catch (_) {
      // Force sign out even if the call fails
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authNotifierProvider);
    final doctorName = authAsync.valueOrNull?.doctorName ?? 'Doctor';
    final specialization =
        authAsync.valueOrNull?.specialization ?? 'Specialist';
    final role = authAsync.valueOrNull?.role ?? UserRole.assistant;
    final initials = _buildInitials(doctorName);
    final screens = <Widget>[
      const DashboardScreen(),
      const PatientListScreen(),
      const ClinicalEntryScreen(),
      role == UserRole.assistant
          ? const MyFollowupsScreen()
          : const DrVisitScreen(),
    ];
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded),
        label: 'Dashboard',
      ),
      const NavigationDestination(
        icon: Icon(Icons.people_outlined),
        selectedIcon: Icon(Icons.people_rounded),
        label: 'Patients',
      ),
      const NavigationDestination(
        icon: Icon(Icons.medical_services_outlined),
        selectedIcon: Icon(Icons.medical_services_rounded),
        label: 'Clinical',
      ),
      NavigationDestination(
        icon: Icon(
          role == UserRole.assistant
              ? Icons.add_task_rounded
              : Icons.health_and_safety_rounded,
        ),
        selectedIcon: Icon(
          role == UserRole.assistant
              ? Icons.add_task_rounded
              : Icons.health_and_safety_rounded,
        ),
        label: role == UserRole.assistant ? 'Follow-ups' : 'Dr Visit',
      ),
    ];

    return Scaffold(
      key: _scaffoldKey,

      // ── Side Drawer ──
      drawer: _buildDrawer(
        doctorName: doctorName,
        specialization: specialization,
        initials: initials,
        role: role,
      ),

      // ── AppBar ──
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, size: 24),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: 'Menu',
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'MediFlow',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 6),
            Consumer(
              builder: (context, ref, _) {
                final dotColor =
                    switch (authAsync.valueOrNull?.role ?? UserRole.assistant) {
                  UserRole.headDoctor => AppTheme.primaryTeal,
                  UserRole.doctor => const Color(0xFF3182CE),
                  UserRole.assistant => Colors.amber.shade600,
                };
                return Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          // Notification Bell
          Consumer(
            builder: (context, ref, _) {
              final unreadCount = ref.watch(unreadCountProvider);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded,
                          size: 24),
                      onPressed: () {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const NotificationSheet(),
                        );
                      },
                      tooltip: 'Notifications',
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          constraints:
                              const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),

      // ── Body ──
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),

      // ── Bottom Navigation ──
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgColor,
          boxShadow: [
            BoxShadow(
              color: Color(0xFFA3B1C6),
              offset: Offset(0, -2),
              blurRadius: 8,
            ),
            BoxShadow(
              color: Colors.white,
              offset: Offset(0, -1),
              blurRadius: 4,
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          backgroundColor: AppTheme.bgColor,
          elevation: 0,
          height: 68,
          destinations: destinations,
        ),
      ),
    );
  }

  Widget _buildDrawer({
    required String doctorName,
    required String specialization,
    required String initials,
    required UserRole role,
  }) {
    final avatarColor = switch (role) {
      UserRole.headDoctor => AppTheme.primaryTeal,
      UserRole.doctor => const Color(0xFF3182CE),
      UserRole.assistant => Colors.amber.shade700,
    };
    final rolePillText = switch (role) {
      UserRole.headDoctor => '● Head Doctor · Super Admin',
      UserRole.doctor => '● Doctor',
      UserRole.assistant => '● Agent',
    };

    return Drawer(
      backgroundColor: AppTheme.bgColor,
      width: 280,
      child: SafeArea(
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              decoration: const BoxDecoration(
                color: AppTheme.bgColor,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFA3B1C6),
                    offset: Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: avatarColor,
                      boxShadow: [
                        BoxShadow(
                          color: avatarColor.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    doctorName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    specialization,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: avatarColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: avatarColor,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      rolePillText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: avatarColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(
                    icon: Icons.person_outline_rounded,
                    title: 'My Profile',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/profile');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.bar_chart_rounded,
                    title: 'Analytics',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/analytics');
                    },
                  ),
                  if (ref.watch(isHeadDoctorProvider)) ...[
                    _buildDrawerItem(
                      icon: Icons.people_alt_outlined,
                      title: 'Staff Accounts',
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/staff');
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.history_rounded,
                      title: 'Audit Logs',
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/audit-logs');
                      },
                    ),
                  ],
                  _buildDrawerItem(
                    icon: Icons.info_outline_rounded,
                    title: 'About MediFlow',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/about');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.lock_outline_rounded,
                    title: 'Change Password',
                    onTap: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Change Password coming soon.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Logout
            const Divider(height: 1),
            _buildDrawerItem(
              icon: Icons.logout_rounded,
              title: 'Sign Out',
              color: Colors.red,
              onTap: () {
                Navigator.of(context).pop();
                _confirmLogout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    final itemColor = color ?? AppTheme.textColor;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (color ?? AppTheme.primaryTeal).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color ?? AppTheme.primaryTeal, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: itemColor,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }

  String _buildInitials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'DR';
    if (parts.length == 1) {
      final v = parts.first;
      return v.length >= 2 ? v.substring(0, 2).toUpperCase() : v.toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
