import 'package:flutter/material.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/role_provider.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/dashboard/performance_provider.dart';

class PerformanceDashboardScreen extends ConsumerWidget {
  const PerformanceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isHeadDoctorProvider)) {
      return const Scaffold(
        backgroundColor: AppTheme.bgColor,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: NeuCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.lock_outline_rounded,
                    size: 32,
                    color: AppTheme.textMuted,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Access restricted to Head Doctor only.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final performanceAsync = ref.watch(assistantPerformanceProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text(
          'Assistant Performance',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: performanceAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            Row(
              children: [
                Expanded(child: NeuShimmer(width: double.infinity, height: 96)),
                SizedBox(width: 12),
                Expanded(child: NeuShimmer(width: double.infinity, height: 96)),
                SizedBox(width: 12),
                Expanded(child: NeuShimmer(width: double.infinity, height: 96)),
              ],
            ),
            SizedBox(height: 16),
            NeuShimmer(width: double.infinity, height: 180),
            SizedBox(height: 12),
            NeuShimmer(width: double.infinity, height: 180),
          ],
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: NeuCard(
              child: Text(
                'Failed to load performance data: $error',
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ),
          ),
        ),
        data: (items) {
          final totalAssistants = items.length;
          final totalPatients =
              items.fold<int>(0, (sum, item) => sum + item.patientsRegistered);
          final totalFollowups =
              items.fold<int>(0, (sum, item) => sum + item.followupsTotal);
          final totalCompleted =
              items.fold<int>(0, (sum, item) => sum + item.followupsCompleted);
          final overallRate =
              totalFollowups == 0 ? 0.0 : totalCompleted / totalFollowups * 100;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Assistants',
                      value: '$totalAssistants',
                      icon: AppIcons.people_alt_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Patients',
                      value: '$totalPatients',
                      icon: AppIcons.person_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Follow-up Rate',
                      value: '${overallRate.toStringAsFixed(0)}%',
                      icon: AppIcons.insights_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (items.isEmpty)
                const NeuCard(
                  child: Center(
                    child: Text(
                      'No assistant performance data yet.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                )
              else
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AssistantCard(kpi: item),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryTeal, size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantCard extends StatelessWidget {
  const _AssistantCard({required this.kpi});

  final AssistantKpi kpi;

  @override
  Widget build(BuildContext context) {
    final completionRate = kpi.completionRate;
    final isHighPerformer = completionRate > 80;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _AssistantDetailSheet(kpi: kpi),
      ),
      child: NeuCard(
        borderRadius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.12),
                  child: Text(
                    _initials(kpi.fullName),
                    style: const TextStyle(
                      color: AppTheme.primaryTeal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kpi.fullName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColor,
                        ),
                      ),
                      if (kpi.specialization.isNotEmpty)
                        Text(
                          kpi.specialization,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isHighPerformer)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'High Performer',
                      style: TextStyle(
                        color: AppTheme.successColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Patients',
                    value: kpi.patientsRegistered.toString(),
                    icon: AppIcons.person_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    label: 'Visits',
                    value: kpi.visitsCreated.toString(),
                    icon: AppIcons.health_and_safety_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Done',
                    value: kpi.followupsCompleted.toString(),
                    icon: AppIcons.check_circle_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    label: 'Overdue',
                    value: kpi.followupsOverdue.toString(),
                    icon: AppIcons.warning_rounded,
                    color: kpi.followupsOverdue > 0 ? Colors.red : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Outside Visits',
                    value: kpi.outsideVisitsTotal.toString(),
                    icon: AppIcons.local_hospital_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(child: SizedBox()),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: completionRate / 100,
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.7),
                valueColor: AlwaysStoppedAnimation<Color>(
                  completionRate > 80
                      ? AppTheme.successColor
                      : AppTheme.primaryTeal,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Completion Rate: ${completionRate.toStringAsFixed(0)}%',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'A';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? AppTheme.textColor;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantDetailSheet extends StatelessWidget {
  const _AssistantDetailSheet({required this.kpi});

  final AssistantKpi kpi;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, controller) {
        return NeuCard(
          borderRadius: 28,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kpi.fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textColor,
                        ),
                      ),
                      if (kpi.specialization.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          kpi.specialization,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _DetailRow(
                        label: 'Patients Registered',
                        value: '${kpi.patientsRegistered}',
                      ),
                      _DetailRow(
                        label: 'Visits Created',
                        value: '${kpi.visitsCreated}',
                      ),
                      _DetailRow(
                        label: 'Follow-ups Total',
                        value: '${kpi.followupsTotal}',
                      ),
                      _DetailRow(
                        label: 'Follow-ups Completed',
                        value: '${kpi.followupsCompleted}',
                      ),
                      _DetailRow(
                        label: 'Follow-ups Overdue',
                        value: '${kpi.followupsOverdue}',
                        color: kpi.followupsOverdue > 0 ? Colors.red : null,
                      ),
                      _DetailRow(
                        label: 'Outside Visits',
                        value: '${kpi.outsideVisitsTotal}',
                      ),
                      _DetailRow(
                        label: 'Completion Rate',
                        value: '${kpi.completionRate.toStringAsFixed(0)}%',
                        color: kpi.completionRate > 80
                            ? AppTheme.successColor
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? AppTheme.textColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
