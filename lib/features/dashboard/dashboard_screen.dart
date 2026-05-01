// lib/features/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/parse_utils.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/shared/widgets/skeleton_loader.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/features/dashboard/dashboard_provider.dart';
import 'package:mediflow/features/followups/followup_provider.dart';
import 'package:mediflow/features/followups/followup_task_widget.dart';
import 'package:mediflow/models/user_role.dart';
import 'package:mediflow/shared/widgets/dashboard_stat_carousel.dart';
import 'package:mediflow/shared/widgets/service_status_badge.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final role = authState?.role ?? UserRole.assistant;
    final isAdmin = role.isAdmin;
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
              SliverToBoxAdapter(
                child: _buildHeader(
                  context,
                  greeting,
                  name,
                  role,
                  dashboardAsync.valueOrNull?.isLive ?? false,
                  ref,
                ),
              ),
              dashboardAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: DashboardSkeleton(),
                ),
                error: (error, stack) => SliverToBoxAdapter(
                  child: _buildErrorState(context, ref, error),
                ),
                data: (data) => SliverList(
                  delegate: SliverChildListDelegate([
                    _buildStatCards(data, isAdmin),
                    if (!isAdmin && data.assignedVisits.isNotEmpty) ...[
                      _buildSectionHeader('Assigned to me today'),
                      _buildAssignedVisitsList(data.assignedVisits, context),
                    ],
                    if (!isAdmin && data.followupTasks.isNotEmpty) ...[
                      _buildSectionHeader('Today\'s followups'),
                      _buildFollowupTasksList(data.followupTasks),
                    ],
                    if (isAdmin && data.highPriorityPatients.isNotEmpty) ...[
                      _buildSectionHeader('Requires Immediate Attention'),
                      _buildHighPriorityList(
                          data.highPriorityPatients, isAdmin),
                    ],
                    _buildSectionHeader(
                      isAdmin ? 'Today\'s Visits' : 'Patients Visited Today',
                    ),
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
    UserRole role,
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
                  role.isAdmin ? 'Dr. $name' : name,
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
          _buildRoleBadge(role),
          if (isLive) ...[
            const SizedBox(width: 8),
            _buildLiveBadge(),
          ],
          IconButton(
            icon: const Icon(
              AppIcons.refresh_rounded,
              color: AppTheme.primaryTeal,
              size: 22,
            ),
            onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(UserRole role) {
    final badgeColor = switch (role) {
      UserRole.headDoctor => AppTheme.primaryTeal,
      UserRole.doctor => AppTheme.doctorAccent,
      UserRole.assistant => AppTheme.assistantAccent,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor, width: 0.8),
      ),
      child: Text(
        _getRoleBadgeLabel(role),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: badgeColor,
        ),
      ),
    );
  }

  String _getRoleBadgeLabel(UserRole role) => switch (role) {
        UserRole.headDoctor => 'HEAD DR',
        UserRole.doctor => 'DOCTOR',
        UserRole.assistant => 'AGENT',
      };

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppTheme.successColor.withValues(alpha: 0.4), width: 0.8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(),
          SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.successColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(DashboardState data, bool isAdmin) {
    final items = isAdmin
        ? <DashboardStatItem>[
            DashboardStatItem(
              label: 'Today\'s Visits',
              value: data.stats.todayVisitsCount.toString(),
              icon: AppIcons.calendar_today_rounded,
              color: AppTheme.primaryTeal,
            ),
            DashboardStatItem(
              label: 'Pending Labs',
              value: data.stats.pendingLabsCount.toString(),
              icon: AppIcons.biotech_rounded,
              color: AppTheme.warningColor,
            ),
            DashboardStatItem(
              label: 'OT Scheduled',
              value: data.stats.upcomingOTCount.toString(),
              icon: AppIcons.medical_services_rounded,
              color: AppTheme.errorColor,
            ),
            DashboardStatItem(
              label: 'High Priority',
              value: data.stats.highPriorityCount.toString(),
              icon: AppIcons.priority_high_rounded,
              color: AppTheme.analyticsAccent,
            ),
          ]
        : <DashboardStatItem>[
            DashboardStatItem(
              label: 'My Patients',
              value: '${data.todayVisits.length}',
              icon: AppIcons.people_rounded,
              color: AppTheme.primaryTeal,
            ),
            DashboardStatItem(
              label: 'Follow-ups Due',
              value: '${data.followupTasks.length}',
              icon: AppIcons.add_task_rounded,
              color: AppTheme.warningColor,
            ),
            DashboardStatItem(
              label: 'Visits Today',
              value: '${data.assignedVisits.length}',
              icon: AppIcons.health_and_safety_rounded,
              color: AppTheme.doctorAccent,
            ),
          ];

    return DashboardStatCarousel(
      items: items,
      height: 114,
      cardWidth: 132,
      cardHeight: 100,
      borderRadius: 16,
      useNeuCard: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        itemBuilder: (_, i) =>
            _PriorityCard(patient: patients[i], isAdmin: isAdmin),
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
      itemBuilder: (_, i) =>
          _VisitCard(visit: visits[i], isAdmin: isAdmin, context: context),
    );
  }

  Widget _buildAssignedVisitsList(
    List<Map<String, dynamic>> visits,
    BuildContext context,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: visits.length,
      itemBuilder: (_, i) =>
          _AssignedVisitCard(visit: visits[i], context: context),
    );
  }

  Widget _buildFollowupTasksList(List<FollowupTask> tasks) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: tasks.length,
      itemBuilder: (_, i) => FollowupTaskWidget(task: tasks[i]),
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
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: NeuCard(
        child: Center(
          child: Column(
            children: [
              Icon(
                AppIcons.event_available_rounded,
                size: 52,
                color: AppTheme.textMuted,
              ),
              SizedBox(height: 12),
              Text(
                'No visits recorded today',
                style: TextStyle(
                  color: AppTheme.textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Visits logged today will appear here',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: NeuCard(
        child: Column(
          children: [
            const Icon(
              AppIcons.cloud_off_rounded,
              size: 48,
              color: AppTheme.textMuted,
            ),
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
                style: TextStyle(
                  color: AppTheme.surfaceWhite,
                  fontWeight: FontWeight.w600,
                ),
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
        border: const Border(
            left: BorderSide(color: AppTheme.errorColor, width: 4)),
        boxShadow: const [
          BoxShadow(
            color: AppTheme.neuShadowDark,
            offset: Offset(3, 3),
            blurRadius: 6,
          ),
          BoxShadow(
            color: AppTheme.surfaceWhite,
            offset: Offset(-3, -3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              const Icon(
                AppIcons.warning_amber_rounded,
                size: 13,
                color: AppTheme.errorColor,
              ),
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
                  const Icon(
                    AppIcons.person_outline_rounded,
                    size: 11,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      'by ${patient['last_updated_by']}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                      ),
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

class _AssignedVisitCard extends StatelessWidget {
  final Map<String, dynamic> visit;
  final BuildContext context;

  const _AssignedVisitCard({required this.visit, required this.context});

  @override
  Widget build(BuildContext _) {
    final patientInfo = visit['patients'] as Map<String, dynamic>?;
    final patientName = patientInfo?['full_name'] ?? 'Unknown';
    final visitTime = visit['visit_date'] != null
        ? DateFormat.jm()
            .format(parseDbDateOr(visit['visit_date'], DateTime.now()))
        : '--:--';
    final followupStatus = visit['followup_status'] ?? 'pending';

    return GestureDetector(
      onTap: () => context.push('/dr-visits/${visit['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.bgColor,
          borderRadius: BorderRadius.circular(16),
          border: const Border(
            left: BorderSide(color: AppTheme.primaryTeal, width: 4),
          ),
          boxShadow: const [
            BoxShadow(
              color: AppTheme.surfaceWhite,
              offset: Offset(-2, -2),
              blurRadius: 6,
            ),
            BoxShadow(
              color: AppTheme.neuShadowDark,
              offset: Offset(2, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Visit at $visitTime',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              ServiceStatusBadge(status: followupStatus, size: 9),
            ],
          ),
        ),
      ),
    );
  }
}

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
        ? DateFormat.jm()
            .format(parseDbDateOr(visit['visit_date'], DateTime.now()))
        : '--:--';
    final status =
        (visit['patient_flow_status'] ?? 'admitted').toString().toLowerCase();
    final addedBy = visit['last_updated_by'] as String?;

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
                  ? AppTheme.errorColor
                  : AppTheme.primaryTeal.withValues(alpha: 0.4),
              width: isHighPriority ? 4 : 2,
            ),
          ),
          boxShadow: const [
            BoxShadow(
              color: AppTheme.surfaceWhite,
              offset: Offset(-2, -2),
              blurRadius: 6,
            ),
            BoxShadow(
              color: AppTheme.neuShadowDark,
              offset: Offset(2, 2),
              blurRadius: 6,
            ),
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
                  ServiceStatusBadge(status: status, size: 9),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  _MiniChip(
                    icon: AppIcons.access_time_rounded,
                    label: visitTime,
                    color: AppTheme.textMuted,
                  ),
                  _MiniChip(
                    icon: AppIcons.category_rounded,
                    label: visit['visit_type'] ?? 'OPD',
                    color: AppTheme.primaryTeal,
                  ),
                  if (visit['tests_performed'] != null)
                    _MiniChip(
                      icon: visit['tests_performed'] == true
                          ? AppIcons.check_circle_rounded
                          : AppIcons.pending_rounded,
                      label: visit['tests_performed'] == true
                          ? 'Labs Done'
                          : 'Labs Pending',
                      color: visit['tests_performed'] == true
                          ? AppTheme.successColor
                          : AppTheme.warningColor,
                    ),
                ],
              ),
              if (isAdmin && addedBy != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      AppIcons.person_outline_rounded,
                      size: 12,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Recorded by Dr. $addedBy',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
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
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MiniChip({
    required this.icon,
    required this.label,
    required this.color,
  });

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
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
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
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
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
          color: AppTheme.successColor,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
