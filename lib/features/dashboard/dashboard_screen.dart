// lib/features/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/role_provider.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/features/dashboard/dashboard_provider.dart';
import 'package:mediflow/models/user_role.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final authState = ref.watch(authNotifierProvider).value;
    final isAdmin = ref.watch(isAdminProvider);
    final name = authState?.doctorName ?? (isAdmin ? 'Doctor' : 'Assistant');
    final greeting = _greeting();

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal)),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (data) => RefreshIndicator(
            color: AppTheme.primaryTeal,
            onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
            child: CustomScrollView(
              slivers: [
                // ── HEADER ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(greeting, style: const TextStyle(
                                fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
                              Text('Dr. $name', style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textColor),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        _roleBadge(isAdmin),
                        const SizedBox(width: 8),
                        if (data.isLive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade400),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 6, height: 6,
                                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                                const SizedBox(width: 4),
                                const Text('LIVE', style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryTeal),
                          onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── STAT CARDS ──
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 108,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: [
                        _statCard('Today\'s Visits', data.appointmentsCount.toString(),
                          Icons.calendar_today_rounded, AppTheme.primaryTeal),
                        const SizedBox(width: 12),
                        _statCard('Pending Labs', data.pendingLabsCount.toString(),
                          Icons.biotech_rounded, const Color(0xFFD97706)),
                        const SizedBox(width: 12),
                        _statCard('OT Scheduled', data.upcomingOTCount.toString(),
                          Icons.medical_services_rounded, const Color(0xFFDC2626)),
                        if (isAdmin) ...[
                          const SizedBox(width: 12),
                          _statCard('High Priority', data.highPriorityPatients.length.toString(),
                            Icons.priority_high_rounded, Colors.deepPurple),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── HIGH PRIORITY (doctors see who added them) ──
                if (data.highPriorityPatients.isNotEmpty) ...[
                  _sectionHeader('🔴 Requires Immediate Attention'),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: isAdmin ? 110 : 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: data.highPriorityPatients.length,
                        itemBuilder: (_, i) {
                          final p = data.highPriorityPatients[i];
                          return _priorityCard(p, isAdmin);
                        },
                      ),
                    ),
                  ),
                ],

                // ── TODAY'S VISITS ──
                _sectionHeader('📋 Today\'s Visits'),
                data.todayVisits.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.event_available_rounded,
                                  size: 56, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text('No visits recorded today',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _visitCard(data.todayVisits[i], isAdmin),
                          childCount: data.todayVisits.length,
                        ),
                      ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  Widget _roleBadge(bool isAdmin) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: isAdmin
          ? AppTheme.primaryTeal.withValues(alpha: 0.1)
          : Colors.amber.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: isAdmin ? AppTheme.primaryTeal : Colors.amber.shade700, width: 0.8),
    ),
    child: Text(
      isAdmin ? 'ADMIN' : 'ASSISTANT',
      style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.bold,
        color: isAdmin ? AppTheme.primaryTeal : Colors.amber.shade700),
    ),
  );

  Widget _statCard(String label, String value, IconData icon, Color color) =>
    Container(
      width: 130,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.white, offset: Offset(-3, -3), blurRadius: 8),
          BoxShadow(color: Color(0xFFA3B1C6), offset: Offset(3, 3), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(
                fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );

  SliverToBoxAdapter _sectionHeader(String title) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Text(title, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700,
        color: AppTheme.textColor, letterSpacing: 0.3)),
    ),
  );

  Widget _priorityCard(Map<String, dynamic> p, bool isAdmin) => Container(
    width: isAdmin ? 180 : 155,
    margin: const EdgeInsets.only(right: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.bgColor,
      borderRadius: BorderRadius.circular(14),
      border: const Border(left: BorderSide(color: Colors.red, width: 4)),
      boxShadow: const [
        BoxShadow(color: Color(0xFFA3B1C6), offset: Offset(3, 3), blurRadius: 6),
        BoxShadow(color: Colors.white, offset: Offset(-3, -3), blurRadius: 6),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 13, color: Colors.red),
            const SizedBox(width: 4),
            Expanded(child: Text(p['full_name'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
        const SizedBox(height: 4),
        Text(p['service_status'] ?? 'Pending',
          style: const TextStyle(fontSize: 11, color: Colors.grey)),
        if (isAdmin && p['last_updated_by'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                const Icon(Icons.person_add_alt_1_rounded, size: 11, color: Colors.blueGrey),
                const SizedBox(width: 3),
                Expanded(child: Text('by ${p['last_updated_by']}',
                  style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _visitCard(Map<String, dynamic> visit, bool isAdmin) {
    final patientInfo = visit['patients'] as Map<String, dynamic>?;
    final patientName = patientInfo?['full_name'] ?? visit['patient_name'] ?? 'Unknown';
    final isHighPriority = patientInfo?['is_high_priority'] ?? false;
    final visitTime = visit['visit_date'] != null
        ? DateFormat.jm().format(DateTime.parse(visit['visit_date']))
        : '--:--';
    final status = (visit['patient_flow_status'] ?? 'admitted').toString().toLowerCase();
    final testStatus = (visit['test_status'] ?? 'pending').toString().toLowerCase();
    final addedBy = visit['last_updated_by'] as String?;

    Color statusColor = Colors.amber.shade700;
    if (status == 'discharged') statusColor = Colors.green;
    if (status == 'referred') statusColor = Colors.blue;
    if (status == 'admitted' || status == 'under observation') statusColor = const Color(0xFFD97706);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: AppTheme.bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: isHighPriority ? Colors.red : AppTheme.primaryTeal.withValues(alpha: 0.3),
            width: isHighPriority ? 4 : 2,
          ),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 6),
          BoxShadow(color: Color(0xFFA3B1C6), offset: Offset(2, 2), blurRadius: 6),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(patientName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor, width: 0.8),
                  ),
                  child: Text(status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip(Icons.access_time_rounded, visitTime, Colors.grey),
                const SizedBox(width: 8),
                _chip(Icons.category_rounded, visit['visit_type'] ?? 'OPD', AppTheme.primaryTeal),
                const SizedBox(width: 8),
                _chip(
                  testStatus == 'done' ? Icons.check_circle_rounded : Icons.pending_rounded,
                  'Labs ${testStatus == 'done' ? 'Done' : 'Pending'}',
                  testStatus == 'done' ? Colors.green : Colors.orange,
                ),
              ],
            ),
            if (isAdmin && addedBy != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text('Recorded by Dr. $addedBy',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    ],
  );
}
