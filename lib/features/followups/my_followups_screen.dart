import 'package:flutter/material.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/followups/followup_provider.dart';
import 'package:mediflow/features/followups/followup_task_widget.dart';

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
          'My Follow-ups',
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
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (_, index) =>
                        FollowupTaskWidget(task: filtered[index]),
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
              error: (error, _) => _buildError(error),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'record-outside-visit',
            backgroundColor: const Color(0xFF3182CE),
            tooltip: 'Record outside doctor visit',
            onPressed: () async {
              final result = await context.push<bool>('/agent-visits/new');
              if (result == true) {
                ref.read(followupTasksProvider.notifier).refresh();
              }
            },
            child: const Icon(AppIcons.local_hospital_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'view-outside-visits',
            backgroundColor: AppTheme.primaryTeal,
            onPressed: () => context.push('/agent-visits'),
            icon: const Icon(AppIcons.history_rounded,
                color: Colors.white, size: 18),
            label: const Text(
              'My Outside Visits',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
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
          const Icon(AppIcons.add_task_rounded,
              size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          Text(
            _filter == _FollowupFilter.all
                ? 'No follow-ups assigned'
                : 'No follow-ups in "${_filter.label}"',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Follow-up tasks from doctors will appear here.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: NeuCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.error_outline_rounded,
                  size: 40, color: AppTheme.errorColor),
              const SizedBox(height: 12),
              const Text(
                'Failed to load follow-ups',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString().length > 120
                    ? '${error.toString().substring(0, 120)}...'
                    : error.toString(),
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              NeuButton(
                onPressed: () =>
                    ref.read(followupTasksProvider.notifier).refresh(),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
