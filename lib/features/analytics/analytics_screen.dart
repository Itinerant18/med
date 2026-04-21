import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/role_provider.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/analytics/analytics_provider.dart';

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
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      backgroundColor: AppTheme.bgColor,
      body: hasAccess
          ? RefreshIndicator(
              color: AppTheme.primaryTeal,
              onRefresh: () => _refresh(ref),
              child: ref.watch(analyticsSummaryProvider).when(
                    loading: () => _AnalyticsLoading(isHeadDoctor: isHeadDoctor),
                    error: (error, _) => _AnalyticsError(
                      message: error.toString(),
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
                Icons.lock_outline_rounded,
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
                Icons.error_outline_rounded,
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
                message.length > 140 ? '${message.substring(0, 140)}...' : message,
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
        const SectionTitle(title: 'Overview', icon: Icons.analytics_outlined),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) =>
                const NeuShimmer(width: 130, height: 100, borderRadius: 18),
          ),
        ),
        const SizedBox(height: 20),
        const SectionTitle(
          title: 'Visits by Type',
          icon: Icons.medical_services_outlined,
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
          icon: Icons.show_chart_rounded,
        ),
        const NeuShimmer(width: double.infinity, height: 200, borderRadius: 18),
        if (isHeadDoctor) ...[
          const SizedBox(height: 20),
          const SectionTitle(
            title: 'Health Scheme Breakdown',
            icon: Icons.account_tree_outlined,
          ),
          const NeuShimmer(
            width: double.infinity,
            height: 190,
            borderRadius: 18,
          ),
          const SizedBox(height: 20),
          const SectionTitle(
            title: 'Staff Performance Table',
            icon: Icons.groups_rounded,
          ),
          const NeuShimmer(
            width: double.infinity,
            height: 260,
            borderRadius: 18,
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
        const SectionTitle(title: 'Overview', icon: Icons.analytics_outlined),
        _OverviewRow(summary: summary),
        const SizedBox(height: 20),
        const SectionTitle(
          title: 'Visits by Type',
          icon: Icons.medical_services_outlined,
        ),
        _VisitTypeSection(summary: summary),
        const SizedBox(height: 20),
        const SectionTitle(
          title: 'Last 30 Days Activity',
          icon: Icons.show_chart_rounded,
        ),
        _ActivityChart(summary: summary),
        if (isHeadDoctor) ...[
          const SizedBox(height: 20),
          const SectionTitle(
            title: 'Health Scheme Breakdown',
            icon: Icons.account_tree_outlined,
          ),
          _SchemeBreakdown(summary: summary),
          const SizedBox(height: 20),
          const SectionTitle(
            title: 'Staff Performance Table',
            icon: Icons.groups_rounded,
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
    final cards = [
      _OverviewCardData(
        title: 'Total Patients',
        value: '${summary.totalPatients}',
        icon: Icons.people_rounded,
        color: AppTheme.primaryTeal,
      ),
      _OverviewCardData(
        title: "Today's Visits",
        value: '${summary.todayVisits}',
        icon: Icons.calendar_today_rounded,
        color: AppTheme.primaryTeal,
      ),
      _OverviewCardData(
        title: 'Clinical Visits',
        value: '${summary.totalVisits}',
        icon: Icons.medical_services_rounded,
        color: const Color(0xFF3182CE),
      ),
      _OverviewCardData(
        title: 'High Priority',
        value: '${summary.highPriorityPatients}',
        icon: Icons.priority_high_rounded,
        color: AppTheme.errorColor,
      ),
      _OverviewCardData(
        title: 'Avg Visits/Day',
        value: summary.avgVisitsPerDay.toStringAsFixed(1),
        icon: Icons.insights_rounded,
        color: const Color(0xFF805AD5),
      ),
      _OverviewCardData(
        title: 'Followup Rate',
        value: '${(summary.followupCompletion * 100).toStringAsFixed(0)}%',
        icon: Icons.event_repeat_rounded,
        color: const Color(0xFFDD6B20),
      ),
    ];

    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _OverviewCard(card: cards[index]),
      ),
    );
  }
}

class _OverviewCardData {
  const _OverviewCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.card});

  final _OverviewCardData card;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 100,
      child: NeuCard(
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: card.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(card.icon, color: card.color, size: 19),
            ),
            const Spacer(),
            Text(
              card.value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textColor,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              card.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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
      borderRadius: 18,
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
      borderRadius: 18,
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
      ('other', 'Other', Colors.grey),
    ];

    return NeuCard(
      borderRadius: 18,
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
            borderRadius: 18,
            child: SizedBox(
              height: 220,
              child: Center(
                child: NeuShimmer(width: double.infinity, height: 180),
              ),
            ),
          ),
          error: (error, _) => NeuCard(
            borderRadius: 18,
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          data: (rows) {
            final sortedRows = [...rows]
              ..sort((a, b) => descending
                  ? b.visitsCount.compareTo(a.visitsCount)
                  : a.visitsCount.compareTo(b.visitsCount));

            return NeuCard(
              borderRadius: 18,
              padding: const EdgeInsets.all(0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 720),
                  child: Column(
                    children: [
                      _TableHeader(
                        descending: descending,
                        onToggleSort: () => ref
                            .read(_staffSortDescendingProvider.notifier)
                            .state = !descending,
                      ),
                      SizedBox(
                        height: math.min(
                          math.max(sortedRows.length * 52.0, 52.0),
                          320.0,
                        ),
                        child: ListView.builder(
                          itemCount: sortedRows.length,
                          itemBuilder: (context, index) => _TableRow(
                            item: sortedRows[index],
                            useAlt: index.isOdd,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.descending,
    required this.onToggleSort,
  });

  final bool descending;
  final VoidCallback onToggleSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        children: [
          const _HeaderCell('Name', 170),
          const _HeaderCell('Role', 90),
          const _HeaderCell('Patients', 80),
          SizedBox(
            width: 80,
            child: InkWell(
              onTap: onToggleSort,
              child: Row(
                children: [
                  const Text(
                    'Visits',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    descending
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    size: 14,
                    color: AppTheme.primaryTeal,
                  ),
                ],
              ),
            ),
          ),
          const _HeaderCell('Dr Visits', 90),
          const _HeaderCell('Followups Done', 110),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, this.width);

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMuted,
        ),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.item,
    required this.useAlt,
  });

  final StaffPerformance item;
  final bool useAlt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: useAlt
          ? Colors.white.withValues(alpha: 0.5)
          : AppTheme.bgColor,
      child: Row(
        children: [
          _BodyCell(item.doctorName, 170, bold: true),
          _BodyCell(item.role.replaceAll('_', ' '), 90),
          _BodyCell('${item.patientsCount}', 80),
          _BodyCell('${item.visitsCount}', 80),
          _BodyCell('${item.drVisitsCount}', 90),
          _BodyCell('${item.followupsCompleted}', 110),
        ],
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell(this.label, this.width, {this.bold = false});

  final String label;
  final double width;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: AppTheme.textColor,
        ),
      ),
    );
  }
}

class _BarChart extends CustomPainter {
  _BarChart(this.points);

  final List<DailyVisitCount> points;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 6.0;
    const bottomPadding = 24.0;
    const maxBarHeight = 120.0;
    final usableHeight = math.min(maxBarHeight, size.height - bottomPadding - 8);
    final usableWidth = size.width - leftPadding * 2;
    final barWidth = points.isEmpty ? 0.0 : usableWidth / points.length;
    final maxCount = points.fold<int>(0, (max, item) => math.max(max, item.count));

    final barPaint = Paint()
      ..color = AppTheme.primaryTeal.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    final labelStyle = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

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
        labelStyle.text = TextSpan(
          text: '${point.date.day}',
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        );
        labelStyle.layout(minWidth: barWidth);
        labelStyle.paint(
          canvas,
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
