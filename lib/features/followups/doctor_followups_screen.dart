// lib/features/followups/doctor_followups_screen.dart
//
// Doctor / head doctor view of follow-up tasks they assigned.
//
// Tabs:
//   • All        — every task created by this doctor
//   • Pending    — not completed yet (pending / in_progress / overdue)
//   • Needs Review — completed by an assistant but not yet acknowledged
//   • Reviewed   — fully closed loop
//
// Tapping a card opens FollowupReviewScreen via /followups/review/:taskId.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/dr_visits/agents_provider.dart';
import 'package:mediflow/features/followups/followup_provider.dart';

enum _DoctorFollowupTab { all, pending, needsReview, reviewed }

extension on _DoctorFollowupTab {
  String get label => switch (this) {
        _DoctorFollowupTab.all => 'All',
        _DoctorFollowupTab.pending => 'Pending',
        _DoctorFollowupTab.needsReview => 'Needs Review',
        _DoctorFollowupTab.reviewed => 'Reviewed',
      };

  bool matches(FollowupTask t) {
    switch (this) {
      case _DoctorFollowupTab.all:
        return true;
      case _DoctorFollowupTab.pending:
        return t.status == 'pending' ||
            t.status == 'in_progress' ||
            t.status == 'overdue';
      case _DoctorFollowupTab.needsReview:
        return t.needsReview;
      case _DoctorFollowupTab.reviewed:
        return t.isReviewed;
    }
  }
}

class DoctorFollowupsScreen extends ConsumerStatefulWidget {
  const DoctorFollowupsScreen({super.key});

  @override
  ConsumerState<DoctorFollowupsScreen> createState() =>
      _DoctorFollowupsScreenState();
}

class _DoctorFollowupsScreenState
    extends ConsumerState<DoctorFollowupsScreen> {
  _DoctorFollowupTab _tab = _DoctorFollowupTab.needsReview;

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(doctorAssignedFollowupsProvider);
    final agentsAsync = ref.watch(agentsProvider);
    final agentNameById = <String, String>{
      for (final a in agentsAsync.valueOrNull ?? const []) a.id: a.fullName,
    };

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Follow-ups I assigned',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.invalidate(doctorAssignedFollowupsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: _DoctorFollowupTab.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final t = _DoctorFollowupTab.values[i];
                final selected = t == _tab;
                final count = tasksAsync.valueOrNull
                        ?.where((task) => t.matches(task))
                        .length ??
                    0;
                return ChoiceChip(
                  label: Text('${t.label} ($count)'),
                  selected: selected,
                  onSelected: (_) => setState(() => _tab = t),
                );
              },
            ),
          ),
          Expanded(
            child: tasksAsync.when(
              data: (tasks) {
                final filtered =
                    tasks.where((t) => _tab.matches(t)).toList();
                if (filtered.isEmpty) return _buildEmptyState();
                return RefreshIndicator(
                  color: AppTheme.primaryTeal,
                  onRefresh: () async {
                    ref.invalidate(doctorAssignedFollowupsProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _DoctorFollowupCard(
                      task: filtered[i],
                      agentName: agentNameById[filtered[i].assignedTo],
                      onTap: () => context.push(
                        '/followups/review/${filtered[i].id}',
                      ),
                    ),
                  ),
                );
              },
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 4,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: NeuShimmer(
                      width: double.infinity,
                      height: 96,
                      borderRadius: 16),
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: NeuCard(
                    child: Text(
                      'Failed to load follow-ups: $e',
                      style: const TextStyle(color: AppTheme.errorColor),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fact_check_outlined,
              size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          Text(
            _tab == _DoctorFollowupTab.all
                ? "You haven't assigned any follow-ups yet"
                : 'Nothing in "${_tab.label}"',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Use the + button on the Dr Visit tab to assign one.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DoctorFollowupCard extends StatelessWidget {
  const _DoctorFollowupCard({
    required this.task,
    required this.agentName,
    required this.onTap,
  });

  final FollowupTask task;
  final String? agentName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOverdue = task.isOverdue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: NeuCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.patientName ?? 'Unknown patient',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _statusChip(task),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.assignment_ind_outlined,
                      size: 13, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Assigned to: ${agentName ?? "Assistant"}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 13,
                      color: isOverdue
                          ? AppTheme.errorColor
                          : AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Due ${DateFormat('MMM d, yyyy').format(task.dueDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue
                          ? AppTheme.errorColor
                          : AppTheme.textMuted,
                      fontWeight:
                          isOverdue ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              if (task.needsReview) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fact_check_outlined,
                          size: 14, color: AppTheme.warningColor),
                      SizedBox(width: 6),
                      Text(
                        'Tap to review',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(FollowupTask t) {
    final (label, color) = _chipFor(t);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  (String, Color) _chipFor(FollowupTask t) {
    if (t.isReviewed) return ('REVIEWED', AppTheme.successColor);
    if (t.needsReview) return ('NEEDS REVIEW', AppTheme.warningColor);
    if (t.isOverdue) return ('OVERDUE', AppTheme.errorColor);
    if (t.status == 'in_progress') {
      return ('IN PROGRESS', const Color(0xFF3182CE));
    }
    if (t.status == 'cancelled') return ('CANCELLED', AppTheme.textMuted);
    return ('PENDING', AppTheme.warningColor);
  }
}
