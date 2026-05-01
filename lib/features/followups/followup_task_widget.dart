import 'package:flutter/material.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/followups/followup_provider.dart';

/// Card the assistant sees on the Follow-ups tab.
///
/// Surfaces, in order of importance to the assistant:
///   1. Patient name + status / priority badges + due date
///   2. Target external doctor & hospital (where to take the patient)
///   3. Doctor's instructions (what to do at the visit)
///   4. Two explicit action buttons:
///        • Record Outside Visit  → opens AgentOutsideVisitForm pre-filled
///        • Mark Done             → simple completion (no external visit)
class FollowupTaskWidget extends ConsumerWidget {
  final FollowupTask task;

  const FollowupTaskWidget({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOverdue = task.isOverdue;
    final isCompleted = task.status == 'completed';
    final isInProgress = task.status == 'in_progress';
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
        child: NeuCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: status badges + due date ──
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatusBadge(
                          label: _statusLabel(task.status),
                          color: _statusColor(task.status),
                        ),
                        if (isUrgent && !isCompleted)
                          const _StatusBadge(
                            label: 'URGENT',
                            color: AppTheme.errorColor,
                          ),
                      ],
                    ),
                  ),
                  Text(
                    'Due ${DateFormat('MMM d').format(task.dueDate)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          isOverdue ? AppTheme.errorColor : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── Patient name + optional title/notes ──
              Text(
                task.patientName ?? 'Unknown Patient',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppTheme.textColor,
                ),
              ),
              if ((task.title?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 2),
                Text(
                  task.title!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
              if ((task.notes?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 4),
                Text(
                  task.notes!,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textMuted, height: 1.35),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // ── Target external doctor (where to go) ──
              if (task.hasTargetDoctor) ...[
                const SizedBox(height: 12),
                _MissionBriefBlock(task: task),
              ],

              // ── Scheduled visit date ──
              if (task.scheduledVisitDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(AppIcons.event_rounded,
                        size: 14, color: AppTheme.primaryTeal),
                    const SizedBox(width: 6),
                    Text(
                      'Scheduled: ${DateFormat('MMM d, yyyy').format(task.scheduledVisitDate!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryTeal,
                      ),
                    ),
                  ],
                ),
              ],

              // ── Doctor's instructions ──
              if ((task.visitInstructions?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                        color: AppTheme.warningColor.withValues(alpha: 0.6),
                        width: 3,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(AppIcons.assignment_outlined,
                          size: 14, color: AppTheme.warningColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'INSTRUCTIONS',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.warningColor,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              task.visitInstructions!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.textColor,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Doctor review (when present) ──
              if (task.isReviewed &&
                  (task.doctorReviewNotes?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(AppIcons.verified_outlined,
                          size: 14, color: AppTheme.successColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DOCTOR REVIEW',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.successColor,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              task.doctorReviewNotes!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.textColor,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Action buttons ──
              if (!isCompleted) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: AppIcons.local_hospital_outlined,
                        label: 'Record What Happened',
                        background: const Color(0xFF3182CE),
                        onTap: () =>
                            _openOutsideVisitForm(context, ref, isInProgress),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: AppIcons.check_rounded,
                        label: 'Mark Done',
                        background: AppTheme.successColor,
                        onTap: () => _openMarkDoneSheet(context, ref),
                      ),
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

  Future<void> _openOutsideVisitForm(
    BuildContext context,
    WidgetRef ref,
    bool isInProgress,
  ) async {
    // Best-effort: flag the task as in-progress when the assistant heads off
    // to record the visit. Idempotent and skipped if it's already that.
    if (!isInProgress) {
      ref.read(followupTasksProvider.notifier).markInProgress(task.id);
    }

    final result = await context.push<bool>(
      '/agent-visits/new',
      extra: {
        'followupTaskId': task.id,
        'patientId': task.patientId,
        'patientName': task.patientName,
        // Pre-fill the assistant's form with what the doctor specified.
        'prefillExtDoctorName': task.targetExtDoctorName,
        'prefillExtDoctorHospital': task.targetExtDoctorHospital,
        'prefillExtDoctorSpecialization': task.targetExtDoctorSpecialization,
        'prefillExtDoctorPhone': task.targetExtDoctorPhone,
        'prefillVisitInstructions': task.visitInstructions,
      },
    );

    if (result == true) {
      ref.read(followupTasksProvider.notifier).refresh();
    }
  }

  Future<void> _openMarkDoneSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CompleteFollowupSheet(task: task),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return 'IN PROGRESS';
      case 'completed':
        return 'COMPLETED';
      case 'overdue':
        return 'OVERDUE';
      case 'cancelled':
        return 'CANCELLED';
      case 'pending':
      default:
        return 'PENDING';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'in_progress':
        return const Color(0xFF3182CE);
      case 'completed':
        return AppTheme.successColor;
      case 'overdue':
        return AppTheme.errorColor;
      case 'cancelled':
        return AppTheme.textMuted;
      case 'pending':
      default:
        return AppTheme.warningColor;
    }
  }
}

class _MissionBriefBlock extends StatelessWidget {
  const _MissionBriefBlock({required this.task});

  final FollowupTask task;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3182CE).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF3182CE).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(AppIcons.assignment_outlined,
                  size: 13, color: Color(0xFF3182CE)),
              SizedBox(width: 6),
              Text(
                'YOUR MISSION',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3182CE),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if ((task.targetExtDoctorName?.isNotEmpty ?? false) ||
              (task.targetExtDoctorHospital?.isNotEmpty ?? false))
            _briefRow(
              AppIcons.local_hospital_outlined,
              'Take ${task.patientName ?? "patient"} to:',
              [
                if (task.targetExtDoctorName?.isNotEmpty ?? false)
                  task.targetExtDoctorName!,
                if (task.targetExtDoctorSpecialization?.isNotEmpty ?? false)
                  task.targetExtDoctorSpecialization!,
                if (task.targetExtDoctorHospital?.isNotEmpty ?? false)
                  task.targetExtDoctorHospital!,
              ].join('  '),
            ),
          if (task.targetExtDoctorPhone?.isNotEmpty ?? false)
            _briefRow(
              AppIcons.phone_rounded,
              'Doctor contact:',
              task.targetExtDoctorPhone!,
            ),
          if (task.scheduledVisitDate != null)
            _briefRow(
              AppIcons.event_rounded,
              'Scheduled for:',
              '${task.scheduledVisitDate!.day}/${task.scheduledVisitDate!.month}/${task.scheduledVisitDate!.year}',
            ),
          if (task.visitInstructions?.isNotEmpty ?? false) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border(
                  left: BorderSide(
                    color: AppTheme.warningColor.withValues(alpha: 0.5),
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                task.visitInstructions!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textColor,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _briefRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF3182CE)),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: AppTheme.textColor),
                children: [
                  TextSpan(
                    text: '$label ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _TargetDoctorBlock extends StatelessWidget {
  const _TargetDoctorBlock({required this.task});

  final FollowupTask task;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if ((task.targetExtDoctorName?.isNotEmpty ?? false))
        task.targetExtDoctorName!,
      if ((task.targetExtDoctorSpecialization?.isNotEmpty ?? false))
        task.targetExtDoctorSpecialization!,
    ];
    final headline = parts.join(' · ');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.primaryTeal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(AppIcons.local_hospital_rounded,
              size: 16, color: AppTheme.primaryTeal),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (headline.isNotEmpty)
                  Text(
                    headline,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textColor,
                    ),
                  ),
                if ((task.targetExtDoctorHospital?.isNotEmpty ?? false))
                  Text(
                    task.targetExtDoctorHospital!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                if ((task.targetExtDoctorPhone?.isNotEmpty ?? false))
                  Text(
                    task.targetExtDoctorPhone!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryTeal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 4),
                const Text(
                  'Take the patient to this doctor and record the outcome.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
      AppSnackbar.showSuccess(context, 'Follow-up marked as completed');
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, AppError.getMessage(e));
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
                'Mark Follow-up Done',
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
                label: 'Completion notes (optional)',
                hint: 'Anything to tell the doctor about this follow-up?',
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
