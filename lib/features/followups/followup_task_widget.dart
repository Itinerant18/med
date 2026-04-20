import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/followups/followup_provider.dart';

class FollowupTaskWidget extends ConsumerWidget {
  final FollowupTask task;

  const FollowupTaskWidget({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOverdue = task.status == 'overdue';
    final isCompleted = task.status == 'completed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          border: isOverdue
              ? Border.all(color: AppTheme.errorColor, width: 2)
              : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: NeuCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          task.patientName ?? 'Unknown Patient',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (isOverdue) ...[
                          const SizedBox(width: 8),
                          const _Badge(
                              label: 'OVERDUE', color: AppTheme.errorColor),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.notes ?? 'No notes provided',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 1.2,
                child: Checkbox(
                  value: isCompleted,
                  activeColor: AppTheme.successColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  onChanged: isCompleted
                      ? null
                      : (val) {
                          if (val == true) {
                            ref
                                .read(followupTasksProvider.notifier)
                                .completeTask(task.id);
                          }
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }
}
