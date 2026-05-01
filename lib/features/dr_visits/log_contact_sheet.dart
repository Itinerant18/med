import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/features/dr_visits/dr_visit_provider.dart';

class LogContactSheet extends ConsumerStatefulWidget {
  const LogContactSheet({super.key, required this.visitId});

  final String visitId;

  @override
  ConsumerState<LogContactSheet> createState() => _LogContactSheetState();
}

class _LogContactSheetState extends ConsumerState<LogContactSheet> {
  final _notesController = TextEditingController();
  bool _isSaving = false;
  String _method = 'call';
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final userId = ref.watch(authNotifierProvider).valueOrNull?.session.user.id;
    if (userId == null) {
      AppSnackbar.showError(context, 'User session not found');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(drVisitsProvider.notifier).addContactAttempt(
        widget.visitId,
        {
          'date': _date.toIso8601String(),
          'method': _method,
          'notes': _notesController.text.trim(),
          'agent_id': userId,
        },
      );
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Contact attempt logged');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, AppError.getMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(
              title: 'Log Contact Attempt',
              icon: AppIcons.call_outlined,
            ),
            NeuCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Method',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _methodChip('call', 'Call'),
                      _methodChip('visit', 'Visit'),
                      _methodChip('whatsapp', 'WhatsApp'),
                      _methodChip('other', 'Other'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _date = picked);
                      }
                    },
                    child: NeuCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      color: AppTheme.bgColor,
                      child: Row(
                        children: [
                          const Icon(
                            AppIcons.calendar_today_rounded,
                            size: 18,
                            color: AppTheme.primaryTeal,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              DateFormat('MMM d, yyyy').format(_date),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  NeuTextField(
                    controller: _notesController,
                    label: 'Notes',
                    hint: 'What happened during this attempt?',
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: NeuButton(
                onPressed: _isSaving ? null : _submit,
                isLoading: _isSaving,
                child: const Text(
                  'LOG ATTEMPT',
                  style: TextStyle(
                    color: AppTheme.primaryForeground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodChip(String value, String label) {
    final selected = _method == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _method = value),
      selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        color: selected ? AppTheme.primaryTeal : AppTheme.textColor,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: selected ? AppTheme.primaryTeal : AppTheme.border,
      ),
    );
  }
}
