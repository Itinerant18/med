import 'package:flutter/material.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/followups/followup_provider.dart';
import 'package:mediflow/features/followups/followup_task_widget.dart';
import 'package:mediflow/shared/widgets/empty_state.dart';
import 'package:mediflow/shared/widgets/error_boundary.dart';

enum _FollowupFilter { all, pending, inProgress, completed, overdue }

extension on _FollowupFilter {
  String get label => switch (this) {
        _FollowupFilter.all => 'All',
        _FollowupFilter.pending => 'Pending',
        _FollowupFilter.inProgress => 'In Progress',
        _FollowupFilter.completed => 'Completed',
        _FollowupFilter.overdue => 'Overdue',
      };

  bool matches(FollowupTask task) {
    switch (this) {
      case _FollowupFilter.all:
        return true;
      case _FollowupFilter.pending:
        return task.status == 'pending';
      case _FollowupFilter.inProgress:
        return task.status == 'in_progress';
      case _FollowupFilter.completed:
        return task.status == 'completed';
      case _FollowupFilter.overdue:
        return task.isOverdue;
    }
  }
}

class MyFollowupsScreen extends ConsumerStatefulWidget {
  const MyFollowupsScreen({super.key});

  @override
  ConsumerState<MyFollowupsScreen> createState() => _MyFollowupsScreenState();
}

class _MyFollowupsScreenState extends ConsumerState<MyFollowupsScreen> {
  _FollowupFilter _filter = _FollowupFilter.all;

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(followupTasksProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'My Tasks',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3),
        ),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.refresh_rounded),
            onPressed: () => ref.read(followupTasksProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: _FollowupFilter.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _FollowupFilter.values[i];
                final selected = f == _filter;
                return ChoiceChip(
                  label: Text(f.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _filter = f),
                );
              },
            ),
          ),
          Expanded(
            child: tasksAsync.when(
              data: (tasks) {
                final filtered =
                    tasks.where((t) => _filter.matches(t)).toList();
                if (filtered.isEmpty) return _buildEmptyState();

                return RefreshIndicator(
                  color: AppTheme.primaryTeal,
                  onRefresh: () =>
                      ref.read(followupTasksProvider.notifier).refresh(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      Container(
                        margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTeal.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryTeal.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(AppIcons.info_outline_rounded,
                                color: AppTheme.primaryTeal, size: 16),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Use "Record Ext. Visit" on a task card to log what happened when you took a patient to an external specialist.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primaryTeal,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...filtered
                          .map((task) => FollowupTaskWidget(task: task)),
                    ],
                  ),
                );
              },
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 4,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: NeuShimmer(
                      width: double.infinity, height: 110, borderRadius: 16),
                ),
              ),
              error: (error, stack) => ErrorBoundary(
                error: error,
                stackTrace: stack,
                contextLabel: 'my_followups',
                title: 'Failed to load follow-ups',
                onRetry: () =>
                    ref.read(followupTasksProvider.notifier).refresh(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'view-external-visits',
        backgroundColor: AppTheme.primaryTeal,
        onPressed: () => context.push('/agent-visits'),
        icon: const Icon(AppIcons.history_rounded,
            color: Colors.white, size: 18),
        label: const Text(
          'My External Visits',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isAll = _filter == _FollowupFilter.all;
    return EmptyState(
      icon: AppIcons.add_task_rounded,
      title: isAll
          ? 'No tasks assigned yet'
          : 'No tasks in "${_filter.label}"',
      subtitle:
          'The doctor assigns you tasks — like taking a patient to a specialist or following up on a referred patient. They will appear here.',
    );
  }

}
