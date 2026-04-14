// lib/features/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:mediflow/core/role_provider.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/features/dashboard/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final authState = ref.watch(authNotifierProvider).value;
    final isAdmin = ref.watch(isAdminProvider);
    final name = authState?.doctorName ?? (isAdmin ? 'Doctor' : 'Staff');
    final greeting = _getGreeting();

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primaryTeal,
          backgroundColor: AppTheme.bgColor,
          onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── HEADER ──
              SliverToBoxAdapter(
                child: _buildHeader(context, greeting, name, isAdmin,
                    dashboardAsync.value?.isLive ?? false, ref),
              ),

              // ── CONTENT ──
              dashboardAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: _DashboardSkeleton(),
                ),
                error: (error, stack) => SliverToBoxAdapter(
                  child: _buildErrorState(context, ref, error),
                ),
                data: (data) => SliverList(
                  delegate: SliverChildListDelegate([
                    _buildStatCards(data, isAdmin),
                    if (data.highPriorityPatients.isNotEmpty) ...[
                      _buildSectionHeader('🔴  Requires Immediate Attention'),
                      _buildHighPriorityList(data.highPriorityPatients, isAdmin),
                    ],
                    _buildSectionHeader('📋  Today\'s Visits'),
                    data.todayVisits.isEmpty
                        ? _buildEmptyVisits()
                        : _buildVisitsList(data.todayVisits, isAdmin, context),
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String greeting,
    String name,
    bool isAdmin,
    bool isLive,
    WidgetRef ref,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Dr. $name',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textColor,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildRoleBadge(isAdmin),
          if (isLive) ...[
            const SizedBox(width: 8),
            _buildLiveBadge(),
          ],
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryTeal, size: 22),
            onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(bool isAdmin) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isAdmin
            ? AppTheme.primaryTeal.withValues(alpha: 0.1)
            : Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAdmin ? AppTheme.primaryTeal : Colors.amber.shade700,
          width: 0.8,
        ),
      ),
      child: Text(
        isAdmin ? 'ADMIN' : 'ASSISTANT',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: isAdmin ? AppTheme.primaryTeal : Colors.amber.shade700,
        ),
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade400, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(),
          const SizedBox(width: 4),
          const Text(
            'LIVE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.green,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(DashboardState data, bool isAdmin) {
    return SizedBox(
      height: 114,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _StatCard(
            label: "Today's Visits",
            value: data.stats.todayVisitsCount.toString(),
            icon: Icons.calendar_today_rounded,
            color: AppTheme.primaryTeal,
          ),
          const SizedBox(width: 12),
          _StatCard(
            label: 'Pending Labs',
            value: data.stats.pendingLabsCount.toString(),
            icon: Icons.biotech_rounded,
            color: const Color(0xFFD97706),
          ),
          const SizedBox(width: 12),
          _StatCard(
            label: 'OT Scheduled',
            value: data.stats.upcomingOTCount.toString(),
            icon: Icons.medical_services_rounded,
            color: const Color(0xFFDC2626),
          ),
          if (isAdmin) ...[
            const SizedBox(width: 12),
            _StatCard(
              label: 'High Priority',
              value: data.stats.highPriorityCount.toString(),
              icon: Icons.priority_high_rounded,
              color: Colors.deepPurple,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHighPriorityList(
    List<Map<String, dynamic>> patients,
    bool isAdmin,
  ) {
    return SizedBox(
      height: isAdmin ? 114 : 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: patients.length,
        itemBuilder: (_, i) => _PriorityCard(patient: patients[i], isAdmin: isAdmin),
      ),
    );
  }

  Widget _buildVisitsList(
    List<Map<String, dynamic>> visits,
    bool isAdmin,
    BuildContext context,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: visits.length,
      itemBuilder: (_, i) => _VisitCard(visit: visits[i], isAdmin: isAdmin, context: context),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.textColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildEmptyVisits() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: NeuCard(
        child: Center(
          child: Column(
            children: [
              Icon(Icons.event_available_rounded,
                  size: 52, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'No visits recorded today',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Visits logged today will appear here',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(
      BuildContext context, WidgetRef ref, Object error) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: NeuCard(
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            const Text(
              'Unable to load dashboard',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              error.toString().length > 100
                  ? '${error.toString().substring(0, 100)}...'
                  : error.toString(),
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            NeuButton(
              onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              child: const Text(
                'Try Again',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Colors.white, offset: Offset(-3, -3), blurRadius: 8),
          BoxShadow(
              color: Color(0xFFA3B1C6), offset: Offset(3, 3), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -1,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Priority Card ─────────────────────────────────────────────────────────────

class _PriorityCard extends StatelessWidget {
  final Map<String, dynamic> patient;
  final bool isAdmin;

  const _PriorityCard({required this.patient, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isAdmin ? 180 : 155,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgColor,
        borderRadius: BorderRadius.circular(14),
        border: const Border(left: BorderSide(color: Colors.red, width: 4)),
        boxShadow: const [
          BoxShadow(
              color: Color(0xFFA3B1C6), offset: Offset(3, 3), blurRadius: 6),
          BoxShadow(
              color: Colors.white, offset: Offset(-3, -3), blurRadius: 6),
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
              Expanded(
                child: Text(
                  patient['full_name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppTheme.textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            patient['service_status'] ?? 'Pending',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          if (isAdmin && patient['last_updated_by'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 11, color: Colors.blueGrey),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      'by ${patient['last_updated_by']}',
                      style: const TextStyle(
                          fontSize: 10, color: Colors.blueGrey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Visit Card ────────────────────────────────────────────────────────────────

class _VisitCard extends StatelessWidget {
  final Map<String, dynamic> visit;
  final bool isAdmin;
  final BuildContext context;

  const _VisitCard({
    required this.visit,
    required this.isAdmin,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    final patientInfo = visit['patients'] as Map<String, dynamic>?;
    final patientName =
        patientInfo?['full_name'] ?? visit['patient_name'] ?? 'Unknown';
    final isHighPriority = patientInfo?['is_high_priority'] ?? false;
    final patientId = visit['patient_id'] as String?;
    final visitTime = visit['visit_date'] != null
        ? DateFormat.jm().format(DateTime.parse(visit['visit_date']))
        : '--:--';
    final status =
        (visit['patient_flow_status'] ?? 'admitted').toString().toLowerCase();
    final addedBy = visit['last_updated_by'] as String?;

    final statusColor = _statusColor(status);

    return GestureDetector(
      onTap: patientId != null
          ? () => context.push('/patients/$patientId/detail')
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: isHighPriority
                  ? Colors.red
                  : AppTheme.primaryTeal.withValues(alpha: 0.4),
              width: isHighPriority ? 4 : 2,
            ),
          ),
          boxShadow: const [
            BoxShadow(
                color: Colors.white, offset: Offset(-2, -2), blurRadius: 6),
            BoxShadow(
                color: Color(0xFFA3B1C6), offset: Offset(2, 2), blurRadius: 6),
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
                    child: Text(
                      patientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textColor,
                      ),
                    ),
                  ),
                  _StatusChip(status: status, color: statusColor),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  _MiniChip(
                      icon: Icons.access_time_rounded,
                      label: visitTime,
                      color: AppTheme.textMuted),
                  _MiniChip(
                      icon: Icons.category_rounded,
                      label: visit['visit_type'] ?? 'OPD',
                      color: AppTheme.primaryTeal),
                  if (visit['tests_performed'] != null)
                    _MiniChip(
                      icon: visit['tests_performed'] == true
                          ? Icons.check_circle_rounded
                          : Icons.pending_rounded,
                      label: visit['tests_performed'] == true
                          ? 'Labs Done'
                          : 'Labs Pending',
                      color: visit['tests_performed'] == true
                          ? Colors.green
                          : Colors.orange,
                    ),
                ],
              ),
              if (isAdmin && addedBy != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'Recorded by Dr. $addedBy',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'discharged':
        return Colors.green;
      case 'referred':
        return Colors.blue;
      case 'admitted':
      case 'under observation':
        return const Color(0xFFD97706);
      default:
        return Colors.amber.shade700;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusChip({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(
        status.toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MiniChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ── Pulse Dot ─────────────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
              color: Colors.green, shape: BoxShape.circle)),
    );
  }
}

// ── Dashboard Skeleton ────────────────────────────────────────────────────────

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat card skeletons
          SizedBox(
            height: 98,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) =>
                  const NeuShimmer(width: 130, height: 98, borderRadius: 16),
            ),
          ),
          const SizedBox(height: 24),
          const NeuShimmer(width: 200, height: 16, borderRadius: 8),
          const SizedBox(height: 12),
          const NeuShimmer(width: double.infinity, height: 80, borderRadius: 16),
          const SizedBox(height: 10),
          const NeuShimmer(width: double.infinity, height: 80, borderRadius: 16),
          const SizedBox(height: 10),
          const NeuShimmer(width: double.infinity, height: 80, borderRadius: 16),
        ],
      ),
    );
  }
}