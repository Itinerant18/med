import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/followups/followup_provider.dart';
import 'package:mediflow/features/followups/followup_task_widget.dart';

class MyFollowupsScreen extends ConsumerWidget {
  const MyFollowupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.read(followupTasksProvider.notifier).refresh(),
          ),
        ],
      ),
      body: tasksAsync.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_task_rounded,
                      size: 64, color: AppTheme.textMuted),
                  SizedBox(height: 12),
                  Text(
                    'No follow-ups assigned',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textColor,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Follow-up tasks from doctors will appear here.',
                    style: TextStyle(
                        color: AppTheme.textMuted, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.primaryTeal,
            onRefresh: () =>
                ref.read(followupTasksProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Column(
                  children: [
                    FollowupTaskWidget(task: task),
                    if (task.status != 'completed')
                      Padding(
                        padding: const EdgeInsets.only(
                            bottom: 16, left: 4, right: 4),
                        child: GestureDetector(
                          onTap: () async {
                            final result = await context.push<bool>(
                              '/agent-visits/new',
                              extra: {
                                'followupTaskId': task.id,
                                'patientId': task.patientId,
                                'patientName': task.patientName,
                              },
                            );
                            if (result == true) {
                              ref
                                  .read(followupTasksProvider.notifier)
                                  .refresh();
                            }
                          },
                          child: const Row(
                            children: [
                              SizedBox(width: 8),
                              Icon(Icons.local_hospital_outlined,
                                  size: 14, color: AppTheme.primaryTeal),
                              SizedBox(width: 6),
                              Text(
                                'Record outside doctor visit for this task',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primaryTeal,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Spacer(),
                              Icon(Icons.arrow_forward_ios_rounded,
                                  size: 11, color: AppTheme.primaryTeal),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          itemBuilder: (_, __) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: NeuShimmer(
                width: double.infinity, height: 90, borderRadius: 16),
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: NeuCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 40, color: AppTheme.errorColor),
                  const SizedBox(height: 12),
                  const Text(
                    'Failed to load follow-ups',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString().length > 120
                        ? '${error.toString().substring(0, 120)}...'
                        : error.toString(),
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  NeuButton(
                    onPressed: () => ref
                        .read(followupTasksProvider.notifier)
                        .refresh(),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 24),
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
        ),
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
            child: const Icon(Icons.local_hospital_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'view-outside-visits',
            backgroundColor: AppTheme.primaryTeal,
            onPressed: () => context.push('/agent-visits'),
            icon: const Icon(Icons.history_rounded,
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
}
