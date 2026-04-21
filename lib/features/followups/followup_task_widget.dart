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
                            borderRadius: BorderRadius.circular(4)),
                        onChanged: isCompleted
                            ? null
                            : (val) async {
                                if (val == true) {
                                  await showModalBottomSheet<void>(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: AppTheme.bgColor,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(24),
                                      ),
                                    ),
                                    builder: (_) =>
                                        _CompleteFollowupSheet(task: task),
                                  );
                                }
                              },
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
}

class _CompleteFollowupSheet extends ConsumerStatefulWidget {
  const _CompleteFollowupSheet({required this.task});

  final FollowupTask task;

  @override
  ConsumerState<_CompleteFollowupSheet> createState() =>
      _CompleteFollowupSheetState();
}

class _CompleteFollowupSheetState extends ConsumerState<_CompleteFollowupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _extNameCtrl = TextEditingController();
  final _extSpecCtrl = TextEditingController();
  final _extHospCtrl = TextEditingController();
  final _extPhoneCtrl = TextEditingController();
  final _completionNotesCtrl = TextEditingController();

  bool _isExternalDoctor = false;
  bool _saving = false;

  @override
  void dispose() {
    _extNameCtrl.dispose();
    _extSpecCtrl.dispose();
    _extHospCtrl.dispose();
    _extPhoneCtrl.dispose();
    _completionNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await ref.read(followupTasksProvider.notifier).completeTask(
            widget.task.id,
            isExternalDoctor: _isExternalDoctor,
            extDoctorName:
                _extNameCtrl.text.trim().isEmpty ? null : _extNameCtrl.text.trim(),
            extDoctorSpecialization: _extSpecCtrl.text.trim().isEmpty
                ? null
                : _extSpecCtrl.text.trim(),
            extDoctorHospital:
                _extHospCtrl.text.trim().isEmpty ? null : _extHospCtrl.text.trim(),
            extDoctorPhone:
                _extPhoneCtrl.text.trim().isEmpty ? null : _extPhoneCtrl.text.trim(),
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
              NeuCard(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Visited external doctor',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ),
                    Switch(
                      value: _isExternalDoctor,
                      onChanged: (value) {
                        setState(() => _isExternalDoctor = value);
                      },
                    ),
                  ],
                ),
              ),
              if (_isExternalDoctor) ...[
                const SizedBox(height: 12),
                NeuTextField(
                  controller: _extNameCtrl,
                  label: 'Doctor Name *',
                  validator: (value) {
                    if (!_isExternalDoctor) return null;
                    if (value == null || value.trim().isEmpty) {
                      return 'Doctor name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                NeuTextField(
                  controller: _extSpecCtrl,
                  label: 'Specialization',
                ),
                const SizedBox(height: 12),
                NeuTextField(
                  controller: _extHospCtrl,
                  label: 'Hospital',
                ),
                const SizedBox(height: 12),
                NeuTextField(
                  controller: _extPhoneCtrl,
                  label: 'Phone',
                  keyboardType: TextInputType.phone,
                ),
              ],
              const SizedBox(height: 12),
              NeuTextField(
                controller: _completionNotesCtrl,
                label: 'Completion Notes',
                hint: 'What happened during follow-up visit?',
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
