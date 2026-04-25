// lib/features/followups/followup_review_screen.dart
//
// Doctor-side review of a completed follow-up task.
//
// Shows:
//   • Task summary (patient + assignee + dates)
//   • What the assistant actually did at the external doctor (joined from
//     agent_outside_visits via followup_task_id)
//   • A free-text "doctor review notes" field
//   • [Acknowledge & Close] — stamps reviewed_by / reviewed_at on the task
//   • [+ Create Follow-up from this] — opens AddFollowupSheet with the same
//     patient pre-selected, so the doctor can chain a follow-up without
//     leaving the screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/agent_visits/agent_outside_visit_provider.dart';
import 'package:mediflow/features/followups/add_followup_sheet.dart';
import 'package:mediflow/features/followups/followup_provider.dart';
import 'package:mediflow/models/agent_outside_visit_model.dart';

class FollowupReviewScreen extends ConsumerStatefulWidget {
  const FollowupReviewScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<FollowupReviewScreen> createState() =>
      _FollowupReviewScreenState();
}

class _FollowupReviewScreenState
    extends ConsumerState<FollowupReviewScreen> {
  final _reviewCtrl = TextEditingController();
  bool _saving = false;
  bool _hasPopulated = false;

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _acknowledge(FollowupTask task) async {
    setState(() => _saving = true);
    try {
      await ref.read(followupTasksProvider.notifier).reviewTask(
            task.id,
            reviewNotes: _reviewCtrl.text.trim().isEmpty
                ? null
                : _reviewCtrl.text.trim(),
          );
      ref.invalidate(doctorAssignedFollowupsProvider);
      ref.invalidate(pendingFollowupReviewCountProvider);
      ref.invalidate(followupTaskByIdProvider(widget.taskId));
      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'Follow-up reviewed');
      context.pop();
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, AppError.getMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chainFollowup(FollowupTask task) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddFollowupSheet(
        preselectedPatientId: task.patientId,
        preselectedPatientName: task.patientName,
      ),
    );
    if (created == true && mounted) {
      AppSnackbar.showSuccess(
          context, 'New follow-up created for ${task.patientName ?? "patient"}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(followupTaskByIdProvider(widget.taskId));

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Review Follow-up',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: taskAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (task) {
          if (task == null) {
            return const Center(
              child: Text(
                'Follow-up not found',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            );
          }

          if (!_hasPopulated &&
              (task.doctorReviewNotes?.isNotEmpty ?? false)) {
            _reviewCtrl.text = task.doctorReviewNotes!;
            _hasPopulated = true;
          }

          final visitAsync =
              ref.watch(agentOutsideVisitForTaskProvider(task.id));

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Task summary ──
                NeuCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.patientName ?? 'Unknown patient',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          _StatusChip(
                            label: task.isReviewed ? 'REVIEWED' : 'NEEDS REVIEW',
                            color: task.isReviewed
                                ? AppTheme.successColor
                                : AppTheme.warningColor,
                          ),
                        ],
                      ),
                      if ((task.title?.isNotEmpty ?? false)) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.title!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      _MetaRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'Due',
                        value: DateFormat('MMM d, yyyy').format(task.dueDate),
                      ),
                      if (task.completedAt != null)
                        _MetaRow(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Completed',
                          value: DateFormat('MMM d, yyyy · HH:mm')
                              .format(task.completedAt!),
                        ),
                      if (task.hasTargetDoctor) ...[
                        const Divider(height: 22),
                        const Text(
                          'TARGET EXTERNAL DOCTOR',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [
                            task.targetExtDoctorName,
                            task.targetExtDoctorSpecialization
                          ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        if ((task.targetExtDoctorHospital?.isNotEmpty ??
                            false))
                          Text(
                            task.targetExtDoctorHospital!,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textMuted),
                          ),
                      ],
                      if ((task.visitInstructions?.isNotEmpty ?? false)) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'INSTRUCTIONS YOU GAVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.visitInstructions!,
                          style: const TextStyle(
                              fontSize: 13, height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Outside visit outcome ──
                visitAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => NeuCard(
                    child: Text(
                      'Could not load outside visit: $e',
                      style: const TextStyle(color: AppTheme.errorColor),
                    ),
                  ),
                  data: (visit) {
                    if (visit == null) {
                      return NeuCard(
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                color: AppTheme.textMuted),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                task.isExternalDoctor
                                    ? 'Assistant marked an external doctor visit but no detailed record was created.'
                                    : 'No external doctor visit was recorded for this follow-up.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return _OutsideVisitCard(visit: visit);
                  },
                ),
                const SizedBox(height: 16),

                // ── Doctor review notes ──
                const SectionTitle(
                  title: 'Your review notes',
                  icon: Icons.edit_note_rounded,
                ),
                NeuTextField(
                  controller: _reviewCtrl,
                  label: 'Clinical follow-up / next steps',
                  hint:
                      'e.g. Patient needs OT evaluation. Schedule re-review in 2 weeks.',
                  maxLines: 4,
                ),
                const SizedBox(height: 20),

                // ── Actions ──
                SizedBox(
                  width: double.infinity,
                  child: NeuButton(
                    onPressed: _saving ? null : () => _acknowledge(task),
                    isLoading: _saving,
                    child: Text(
                      task.isReviewed
                          ? 'UPDATE REVIEW'
                          : 'ACKNOWLEDGE & CLOSE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : () => _chainFollowup(task),
                    icon: const Icon(Icons.add_task_rounded),
                    label: const Text('Create new follow-up from this'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryTeal,
                      side: const BorderSide(color: AppTheme.primaryTeal),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OutsideVisitCard extends StatelessWidget {
  const _OutsideVisitCard({required this.visit});

  final AgentOutsideVisit visit;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_hospital_rounded,
                  color: Color(0xFF3182CE)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'EXTERNAL VISIT OUTCOME',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Text(
                DateFormat('MMM d, yyyy').format(visit.visitDate),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            [
              visit.extDoctorName,
              visit.extDoctorSpecialization,
            ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textColor,
            ),
          ),
          if ((visit.extDoctorHospital?.isNotEmpty ?? false))
            Text(
              visit.extDoctorHospital!,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textMuted),
            ),
          const Divider(height: 22),
          if ((visit.chiefComplaint?.isNotEmpty ?? false))
            _LabelValue(label: 'Chief complaint', value: visit.chiefComplaint!),
          if ((visit.diagnosis?.isNotEmpty ?? false))
            _LabelValue(label: 'Diagnosis', value: visit.diagnosis!),
          if ((visit.prescriptions?.isNotEmpty ?? false))
            _LabelValue(label: 'Prescriptions', value: visit.prescriptions!),
          if ((visit.visitNotes?.isNotEmpty ?? false))
            _LabelValue(label: 'Notes', value: visit.visitNotes!),
          if (visit.nextFollowupDate != null)
            _LabelValue(
              label: 'Next follow-up suggested',
              value: DateFormat('MMM d, yyyy').format(visit.nextFollowupDate!),
            ),
        ],
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
