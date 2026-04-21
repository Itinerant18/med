import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    final isUrgent = task.priority == 'urgent';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: isOverdue
              ? Border.all(color: AppTheme.errorColor, width: 2)
              : null,
        ),
        child: Row(
          children: [
            if (isUrgent)
              Container(
                width: 4,
                height: 92,
                decoration: const BoxDecoration(
                  color: AppTheme.errorColor,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                ),
              ),
            Expanded(
              child: NeuCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 16,
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
                                    label: 'OVERDUE',
                                    color: AppTheme.errorColor),
                              ],
                              if (isUrgent) ...[
                                const SizedBox(width: 8),
                                const _Badge(
                                  label: 'URGENT',
                                  color: AppTheme.errorColor,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            task.title?.isNotEmpty == true
                                ? '${task.title}\n${task.notes ?? 'No notes provided'}'
                                : task.notes ?? 'No notes provided',
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
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: isCompleted
                            ? null
                            : (val) => _handleCheckboxTap(context, val),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCheckboxTap(BuildContext context, bool? val) async {
    if (val != true) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CompleteChoiceSheet(task: task),
    );

    if (!context.mounted) return;

    if (choice == 'direct') {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppTheme.bgColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _CompleteFollowupSheet(task: task),
      );
    } else if (choice == 'outside') {
      await context.push<bool>(
        '/agent-visits/new',
        extra: {
          'followupTaskId': task.id,
          'patientId': task.patientId,
          'patientName': task.patientName,
        },
      );
    }
  }
}

class _CompleteChoiceSheet extends StatelessWidget {
  const _CompleteChoiceSheet({required this.task});

  final FollowupTask task;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How was the follow-up completed?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            task.patientName ?? 'Patient',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ListTile(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: AppTheme.primaryTeal.withValues(alpha: 0.06),
            leading: const Icon(Icons.check_circle_outline_rounded,
                color: AppTheme.primaryTeal),
            title: const Text(
              'Mark as completed',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle:
                const Text('Simple completion without external doctor details'),
            onTap: () => Navigator.pop(context, 'direct'),
          ),
          const SizedBox(height: 12),
          ListTile(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: const Color(0xFF3182CE).withValues(alpha: 0.06),
            leading: const Icon(Icons.local_hospital_outlined,
                color: Color(0xFF3182CE)),
            title: const Text(
              'Record outside doctor visit',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle:
                const Text('Add details of the external doctor visited'),
            onTap: () => Navigator.pop(context, 'outside'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _CompleteFollowupSheet extends ConsumerStatefulWidget {
  const _CompleteFollowupSheet({required this.task});

  final FollowupTask task;

  @override
  ConsumerState<_CompleteFollowupSheet> createState() =>
      _CompleteFollowupSheetState();
}

class _CompleteFollowupSheetState
    extends ConsumerState<_CompleteFollowupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _completionNotesCtrl = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _completionNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await ref.read(followupTasksProvider.notifier).completeTask(
            widget.task.id,
            isExternalDoctor: false,
            completionNotes: _completionNotesCtrl.text.trim().isEmpty
                ? null
                : _completionNotesCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Complete Follow-up',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.task.patientName ?? 'Unknown Patient',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              NeuTextField(
                controller: _completionNotesCtrl,
                label: 'Completion Notes',
                hint: 'What happened during the follow-up?',
                maxLines: 3,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: NeuButton(
                  onPressed: _saving ? null : _submit,
                  isLoading: _saving,
                  child: const Text(
                    'MARK COMPLETED',
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
