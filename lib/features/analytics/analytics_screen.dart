import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/role_provider.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/analytics/analytics_provider.dart';
import 'package:mediflow/shared/widgets/dashboard_stat_carousel.dart';
import 'package:mediflow/core/error_handler.dart';

final _staffSortDescendingProvider =
    StateProvider.autoDispose<bool>((ref) => true);

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(analyticsSummaryProvider);
    ref.invalidate(staffPerformanceProvider);
    await Future.wait([
      ref.read(analyticsSummaryProvider.future),
      ref.read(staffPerformanceProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAccess = ref.watch(isAdminProvider);
    final isHeadDoctor = ref.watch(isHeadDoctorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _refresh(ref),
            icon: const Icon(AppIcons.refresh_rounded),
          ),
        ],
      ),
      backgroundColor: AppTheme.bgColor,
      body: hasAccess
          ? RefreshIndicator(
              color: AppTheme.primaryTeal,
              onRefresh: () => _refresh(ref),
              child: ref.watch(analyticsSummaryProvider).when(
                    loading: () =>
                        _AnalyticsLoading(isHeadDoctor: isHeadDoctor),
                    error: (error, _) => _AnalyticsError(
                      message: AppError.getMessage(error),
                      onRetry: () => _refresh(ref),
                    ),
                    data: (summary) => _AnalyticsBody(
                      summary: summary,
                      isHeadDoctor: isHeadDoctor,
                    ),
                  ),
            )
          : const _NoAccessView(),
    );
  }
}

class _NoAccessView extends StatelessWidget {
  const _NoAccessView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: const [
        SizedBox(height: 80),
        NeuCard(
          child: Column(
            children: [
              Icon(
                AppIcons.lock_outline_rounded,
                size: 48,
                color: AppTheme.textMuted,
              ),
              SizedBox(height: 12),
              Text(
                'No access',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textColor,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Analytics is available only for doctors and head doctors.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalyticsError extends StatelessWidget {
  const _AnalyticsError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 72),
        NeuCard(
          child: Column(
            children: [
              const Icon(
                AppIcons.error_outline_rounded,
                size: 48,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: 12),
              const Text(
                'Failed to load analytics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message.length > 140
                    ? '${message.substring(0, 140)}...'
                    : message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: 160,
                child: NeuButton(
                  onPressed: onRetry,
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalyticsLoading extends StatelessWidget {
  const _AnalyticsLoading({required this.isHeadDoctor});

  final bool isHeadDoctor;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const SectionTitle(
            title: 'Overview', icon: AppIcons.analytics_outlined),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) =>
                const NeuShimmer(width: 130, height: 100, borderRadius: 32),
          ),
        ),
        const SizedBox(height: 20),
        const SectionTitle(
          title: 'Visits by Type',
          icon: AppIcons.medical_services_outlined,
        ),
        const Row(
          children: [
            Expanded(child: NeuShimmer(width: double.infinity, height: 110)),
            SizedBox(width: 12),
            Expanded(child: NeuShimmer(width: double.infinity, height: 110)),
            SizedBox(width: 12),
            Expanded(child: NeuShimmer(width: double.infinity, height: 110)),
          ],
        ),
        const SizedBox(height: 20),
        const SectionTitle(
          title: 'Last 30 Days Activity',
          icon: AppIcons.show_chart_rounded,
        ),
        const NeuShimmer(width: double.infinity, height: 200, borderRadius: 32),
        if (isHeadDoctor) ...[
          const SizedBox(height: 20),
          const SectionTitle(
            title: 'Health Scheme Breakdown',
            icon: AppIcons.account_tree_outlined,
          ),
          const NeuShimmer(
            width: double.infinity,
            height: 190,
            borderRadius: 32,
          ),
          const SizedBox(height: 20),
          const SectionTitle(
            title: 'Staff Performance Table',
            icon: AppIcons.groups_rounded,
          ),
          const NeuShimmer(
            width: double.infinity,
            height: 260,
            borderRadius: 32,
          ),
        ],
      ],
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({
    required this.summary,
    required this.isHeadDoctor,
  });

  final AnalyticsSummary summary;
  final bool isHeadDoctor;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const SectionTitle(
            title: 'Overview', icon: AppIcons.analytics_outlined),
        _OverviewRow(summary: summary),
        const SizedBox(height: 20),
        const SectionTitle(
          title: 'Visits by Type',
          icon: AppIcons.medical_services_outlined,
        ),
        _VisitTypeSection(summary: summary),
        const SizedBox(height: 20),
        const SectionTitle(
          title: 'Last 30 Days Activity',
          icon: AppIcons.show_chart_rounded,
        ),
        _ActivityChart(summary: summary),
        if (isHeadDoctor) ...[
          const SizedBox(height: 20),
          const SectionTitle(
            title: 'Health Scheme Breakdown',
            icon: AppIcons.account_tree_outlined,
          ),
          _SchemeBreakdown(summary: summary),
          const SizedBox(height: 20),
          const SectionTitle(
            title: 'Staff Performance Table',
            icon: AppIcons.groups_rounded,
          ),
          const _StaffPerformanceSection(),
        ],
      ],
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      DashboardStatItem(
        label: 'Total Patients',
        value: '${summary.totalPatients}',
        icon: AppIcons.people_rounded,
        color: AppTheme.primaryTeal,
      ),
      DashboardStatItem(
        label: "Today's Visits",
        value: '${summary.todayVisits}',
        icon: AppIcons.calendar_today_rounded,
        color: AppTheme.primaryTeal,
      ),
      DashboardStatItem(
        label: 'Clinical Visits',
        value: '${summary.totalVisits}',
        icon: AppIcons.medical_services_rounded,
        color: const Color(0xFF3182CE),
      ),
      DashboardStatItem(
        label: 'High Priority',
        value: '${summary.highPriorityPatients}',
        icon: AppIcons.priority_high_rounded,
        color: AppTheme.errorColor,
      ),
      DashboardStatItem(
        label: 'Avg Visits/Day',
        value: summary.avgVisitsPerDay.toStringAsFixed(1),
        icon: AppIcons.insights_rounded,
        color: const Color(0xFF805AD5),
      ),
      DashboardStatItem(
        label: 'Followup Rate',
        value: '${(summary.followupCompletion * 100).toStringAsFixed(0)}%',
        icon: AppIcons.event_repeat_rounded,
        color: const Color(0xFFDD6B20),
      ),
    ];

    return DashboardStatCarousel(
      items: items,
      height: 108,
      cardWidth: 130,
      cardHeight: 100,
      borderRadius: 32,
      useNeuCard: true,
      padding: EdgeInsets.zero,
    );
  }
}

class _VisitTypeSection extends StatelessWidget {
  const _VisitTypeSection({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TypeCard(
            label: 'OPD',
            value: summary.visitsByType['OPD'] ?? 0,
            color: AppTheme.successColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TypeCard(
            label: 'IPD',
            value: summary.visitsByType['IPD'] ?? 0,
            color: const Color(0xFF3182CE),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TypeCard(
            label: 'Emergency',
            value: summary.visitsByType['Emergency'] ?? 0,
            color: AppTheme.errorColor,
          ),
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      borderRadius: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 10,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      borderRadius: 32,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: SizedBox(
        height: 200,
        child: CustomPaint(
          painter: _BarChart(summary.last30DaysVisits),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _SchemeBreakdown extends StatelessWidget {
  const _SchemeBreakdown({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final total = summary.patientsByScheme.values.fold<int>(0, (a, b) => a + b);
    final rows = [
      ('insurance', 'Insurance', const Color(0xFF3182CE)),
      ('cash', 'Cash', AppTheme.successColor),
      ('sastho_sathi', 'Sastho Sathi', AppTheme.primaryTeal),
      ('ayushman_bharat', 'Ayushman Bharat', const Color(0xFF805AD5)),
      ('other', 'Other', Colors.grey),
    ];

    return NeuCard(
      borderRadius: 32,
      child: Column(
        children: rows.map((row) {
          final count = summary.patientsByScheme[row.$1] ?? 0;
          final ratio = total == 0 ? 0.0 : count / total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text(
                    row.$2,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 12,
                      color: Colors.white.withValues(alpha: 0.55),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: ratio,
                          child: Container(color: row.$3),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 38,
                  child: Text(
                    '$count',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StaffPerformanceSection extends ConsumerWidget {
  const _StaffPerformanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final descending = ref.watch(_staffSortDescendingProvider);
    return ref.watch(staffPerformanceProvider).when(
          loading: () => const NeuCard(
            borderRadius: 32,
            child: SizedBox(
              height: 240,
              child: Center(
                child: NeuShimmer(width: double.infinity, height: 200),
              ),
            ),
          ),
          error: (error, _) => NeuCard(
            borderRadius: 32,
            child: Column(
              children: [
                const Icon(
                  AppIcons.error_outline_rounded,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(height: 8),
                Text(
                  AppError.getMessage(error),
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          data: (rows) {
            final sortedRows = [...rows]..sort((a, b) => descending
                ? b.visitsCount.compareTo(a.visitsCount)
                : a.visitsCount.compareTo(b.visitsCount));
            final maxVisits = sortedRows.isEmpty
                ? 1
                : sortedRows.map((e) => e.visitsCount).fold<int>(0, math.max);

            return NeuCard(
              borderRadius: 32,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Assistant performance table',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textColor,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => ref
                            .read(_staffSortDescendingProvider.notifier)
                            .state = !descending,
                        icon: Icon(
                          descending
                              ? AppIcons.arrow_downward_rounded
                              : AppIcons.arrow_upward_rounded,
                          size: 16,
                          color: AppTheme.primaryTeal,
                        ),
                        label: Text(
                          descending ? 'Top visits' : 'Lowest first',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 860),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.neuShadowLight),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: DataTable(
                            showCheckboxColumn: false,
                            columnSpacing: 16,
                            horizontalMargin: 14,
                            dataRowMinHeight: 68,
                            dataRowMaxHeight: 84,
                            headingRowHeight: 48,
                            headingTextStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textMuted,
                              letterSpacing: 0.8,
                            ),
                            dataTextStyle: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textColor,
                              fontWeight: FontWeight.w600,
                            ),
                            headingRowColor: const WidgetStatePropertyAll(
                              AppTheme.bgColor,
                            ),
                            columns: const [
                              DataColumn(label: Text('Assistant')),
                              DataColumn(label: Text('Role')),
                              DataColumn(label: Text('Patients')),
                              DataColumn(label: Text('Visits')),
                              DataColumn(label: Text('Follow-ups')),
                              DataColumn(label: Text('Performance')),
                            ],
                            rows: sortedRows.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              final visitShare = maxVisits == 0
                                  ? 0.0
                                  : item.visitsCount / maxVisits;
                              final isHighPerformer =
                                  item.visitsCount >= maxVisits * 0.8;

                              return DataRow(
                                color: WidgetStatePropertyAll<Color>(
                                  index.isEven
                                      ? AppTheme.bgColor
                                      : AppTheme.cardBg,
                                ),
                                cells: [
                                  DataCell(
                                    _StaffNameCell(item: item),
                                  ),
                                  DataCell(
                                    Text(
                                      item.role.replaceAll('_', ' '),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(item.patientsCount.toString()),
                                  ),
                                  DataCell(
                                    Text(item.visitsCount.toString()),
                                  ),
                                  DataCell(
                                    Text(item.followupsCompleted.toString()),
                                  ),
                                  DataCell(
                                    _StaffPerformanceCell(
                                      visitShare: visitShare,
                                      isHighPerformer: isHighPerformer,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
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

class _StaffNameCell extends StatelessWidget {
  const _StaffNameCell({required this.item});

  final StaffPerformance item;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.12),
          child: Text(
            _initials(item.doctorName),
            style: const TextStyle(
              color: AppTheme.primaryTeal,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 180),
          child: Text(
            item.doctorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.textColor,
            ),
          ),
        ),
      ],
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

class _StaffPerformanceCell extends StatelessWidget {
  const _StaffPerformanceCell({
    required this.visitShare,
    required this.isHighPerformer,
  });

  final double visitShare;
  final bool isHighPerformer;

  @override
  Widget build(BuildContext context) {
    final percentage = (visitShare * 100).clamp(0, 100).toStringAsFixed(0);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: visitShare,
              backgroundColor: AppTheme.neutralLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                isHighPerformer
                    ? AppTheme.successColor
                    : AppTheme.primaryTeal,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Visits share $percentage%',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              if (isHighPerformer)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'High Performer',
                    style: TextStyle(
                      color: AppTheme.successColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarChart extends CustomPainter {
  _BarChart(this.points);

  final List<DailyVisitCount> points;
  final TextPainter _labelPainter = TextPainter(
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  );
  final Map<int, String> _labelCache = {};
  Size? _lastSize;
  List<DailyVisitCount>? _lastPointsRef;
  final Map<int, Offset> _labelOffsets = {};
  double _cachedBarWidth = 0;

  void _updateLayoutCache(Size size, double leftPadding, double barWidth) {
    if (_lastSize == size &&
        identical(_lastPointsRef, points) &&
        _cachedBarWidth == barWidth) {
      return;
    }
    _lastSize = size;
    _lastPointsRef = points;
    _cachedBarWidth = barWidth;
    _labelOffsets.clear();

    for (var i = 0; i < points.length; i++) {
      if (i % 5 == 0 || i == points.length - 1) {
        _labelCache[i] = '${points[i].date.day}';
        _labelOffsets[i] =
            Offset(leftPadding + (barWidth * i), size.height - 18);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 6.0;
    const bottomPadding = 24.0;
    const maxBarHeight = 120.0;
    final usableHeight =
        math.min(maxBarHeight, size.height - bottomPadding - 8);
    final usableWidth = size.width - leftPadding * 2;
    final barWidth = points.isEmpty ? 0.0 : usableWidth / points.length;
    final maxCount =
        points.fold<int>(0, (max, item) => math.max(max, item.count));

    final barPaint = Paint()
      ..color = AppTheme.primaryTeal.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    _updateLayoutCache(size, leftPadding, barWidth);

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final ratio = maxCount == 0 ? 0.0 : point.count / maxCount;
      final barHeight = usableHeight * ratio;
      final x = leftPadding + (barWidth * i) + 1;
      final y = size.height - bottomPadding - barHeight;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, math.max(barWidth - 4, 2), barHeight),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, barPaint);

      if (i % 5 == 0 || i == points.length - 1) {
        _labelPainter.text = TextSpan(
          text: _labelCache[i] ?? '${point.date.day}',
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        );
        _labelPainter.layout(minWidth: barWidth);
        _labelPainter.paint(
          canvas,
          _labelOffsets[i] ??
              Offset(leftPadding + (barWidth * i), size.height - 18),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarChart oldDelegate) {
    return oldDelegate.points != points;
  }
}
