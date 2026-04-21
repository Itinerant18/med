import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/core/role_provider.dart';
import 'package:mediflow/features/dr_visits/dr_visit_provider.dart';
import 'package:mediflow/features/followups/add_followup_sheet.dart';
import 'package:mediflow/models/visit_model.dart';
import 'package:go_router/go_router.dart';

class DrVisitScreen extends ConsumerWidget {
  const DrVisitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(drVisitsProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text('Dr Visits',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        backgroundColor: Colors.transparent,
      ),
      body: visitsAsync.when(
        data: (visits) {
          if (visits.isEmpty) {
            return _buildEmptyState();
          }

          // Group visits by date
          final groupedVisits = <String, List<DrVisit>>{};
          for (final visit in visits) {
            final dateStr = DateFormat('yyyy-MM-dd').format(visit.visitDate);
            groupedVisits.putIfAbsent(dateStr, () => []).add(visit);
          }

          final sortedDates = groupedVisits.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return RefreshIndicator(
            onRefresh: () => ref.refresh(drVisitsProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedDates.length,
              itemBuilder: (context, index) {
                final dateStr = sortedDates[index];
                final dateVisits = groupedVisits[dateStr]!;
                final date = DateTime.parse(dateStr);
                final formattedDate = _getFormattedDate(date);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.only(left: 8, bottom: 12, top: 8),
                      child: Text(
                        formattedDate.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textMuted,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    ...dateVisits.map((visit) => _VisitCard(visit: visit)),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: isAdmin
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'add-followup-dr-visit',
                  backgroundColor: AppTheme.warningColor,
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppTheme.bgColor,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (_) => const AddFollowupSheet(),
                  ),
                  child: const Icon(
                    Icons.add_task_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'new-dr-visit',
                  backgroundColor: AppTheme.primaryTeal,
                  onPressed: () => context.push('/dr-visits/new'),
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: const Text('New Visit',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            )
          : null,
    );
  }

  String _getFormattedDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final visitDate = DateTime(date.year, date.month, date.day);

    if (visitDate == today) return 'Today';
    if (visitDate == yesterday) return 'Yesterday';
    return DateFormat('EEEE, MMM d').format(date);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.health_and_safety_rounded,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No visits recorded',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppTheme.textColor),
          ),
          const SizedBox(height: 6),
          const Text(
            'Visits will appear here once they are created.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final DrVisit visit;

  const _VisitCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _getStatusColor(visit.followupStatus);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => context.push('/dr-visits/${visit.id}'),
        child: NeuCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        AppTheme.primaryTeal.withValues(alpha: 0.1),
                    child: const Icon(Icons.person_rounded,
                        color: AppTheme.primaryTeal, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visit.patientName ?? 'Unknown Patient',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (visit.diagnosis != null &&
                            visit.diagnosis!.isNotEmpty)
                          Text(
                            visit.diagnosis!,
                            style: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  _StatusChip(label: visit.followupStatus, color: statusColor),
                ],
              ),
              if (visit.agentName != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.assignment_ind_outlined,
                        size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'Assigned to: ${visit.agentName}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMuted),
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppTheme.successColor;
      case 'cancelled':
        return AppTheme.errorColor;
      case 'pending':
      default:
        return AppTheme.warningColor;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
