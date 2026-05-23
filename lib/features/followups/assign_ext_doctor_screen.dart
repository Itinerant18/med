// lib/features/followups/assign_ext_doctor_screen.dart
import 'package:flutter/material.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/role_provider.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/features/dr_visits/agents_provider.dart';
import 'package:mediflow/features/followups/followup_provider.dart';
import 'package:mediflow/features/followups/external_doctor_picker_sheet.dart';
import 'package:mediflow/features/staff/external_doctors_provider.dart';

class AssignExtDoctorScreen extends ConsumerStatefulWidget {
  final String? prefillExtDoctorName;
  final String? prefillExtDoctorHospital;
  final String? prefillExtDoctorSpecialization;
  final String? prefillExtDoctorPhone;
  final String? prefillVisitInstructions;
  final String? prefillNotes;

  const AssignExtDoctorScreen({
    super.key,
    this.prefillExtDoctorName,
    this.prefillExtDoctorHospital,
    this.prefillExtDoctorSpecialization,
    this.prefillExtDoctorPhone,
    this.prefillVisitInstructions,
    this.prefillNotes,
  });

  @override
  ConsumerState<AssignExtDoctorScreen> createState() =>
      _AssignExtDoctorScreenState();
}

class _AssignExtDoctorScreenState extends ConsumerState<AssignExtDoctorScreen> {
  final _formKey = GlobalKey<FormState>();

  // SECTION 1 — External Doctor
  final _docNameCtrl = TextEditingController();
  final _docHospitalCtrl = TextEditingController();
  final _docSpecCtrl = TextEditingController();
  final _docPhoneCtrl = TextEditingController();
  ExternalDoctor? _selectedDoctor;

  // SECTION 2 — Visit Instructions
  final _instructionsCtrl = TextEditingController();

  // SECTION 3 — Assignment
  String? _selectedAgentId;
  DateTime? _dueDate;
  DateTime? _scheduledVisitDate;
  String _priority = 'normal';

  // SECTION 4 — Internal notes
  final _notesCtrl = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _docNameCtrl.text = widget.prefillExtDoctorName ?? '';
    _docHospitalCtrl.text = widget.prefillExtDoctorHospital ?? '';
    _docSpecCtrl.text = widget.prefillExtDoctorSpecialization ?? '';
    _docPhoneCtrl.text = widget.prefillExtDoctorPhone ?? '';
    _instructionsCtrl.text = widget.prefillVisitInstructions ?? '';
    _notesCtrl.text = widget.prefillNotes ?? '';

    if (widget.prefillExtDoctorName != null &&
        widget.prefillExtDoctorName!.isNotEmpty) {
      Future.microtask(_tryMatchDirectoryDoctor);
    }
  }

  @override
  void dispose() {
    _docNameCtrl.dispose();
    _docHospitalCtrl.dispose();
    _docSpecCtrl.dispose();
    _docPhoneCtrl.dispose();
    _instructionsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _showDoctorPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ExternalDoctorPickerSheet(
        onSelected: (doctor) {
          Navigator.of(context).pop();
          _applyDoctorSelection(doctor);
        },
      ),
    );
  }

  void _applyDoctorSelection(ExternalDoctor doctor) {
    setState(() {
      _selectedDoctor = doctor;
      _docNameCtrl.text = doctor.name;
      _docHospitalCtrl.text = doctor.hospital ?? '';
      _docSpecCtrl.text = doctor.specialization ?? '';
      _docPhoneCtrl.text = doctor.phone ?? '';
    });
  }

  void _clearDoctorSelection() {
    setState(() {
      _selectedDoctor = null;
      _docNameCtrl.clear();
      _docHospitalCtrl.clear();
      _docSpecCtrl.clear();
      _docPhoneCtrl.clear();
    });
  }

  void _tryMatchDirectoryDoctor() {
    if (!mounted) return;
    final name = _docNameCtrl.text.trim().toLowerCase();
    if (name.isEmpty) return;
    final doctors = ref.read(externalDoctorsProvider).valueOrNull;
    if (doctors == null) return;
    try {
      final match = doctors.firstWhere((d) => d.name.toLowerCase() == name);
      if (mounted) setState(() => _selectedDoctor = match);
    } catch (_) {
      if (mounted) {
        setState(() {
          _selectedDoctor = ExternalDoctor(
            id: 'prefilled_${DateTime.now().millisecondsSinceEpoch}',
            name: widget.prefillExtDoctorName!,
            hospital: widget.prefillExtDoctorHospital,
            specialization: widget.prefillExtDoctorSpecialization,
            phone: widget.prefillExtDoctorPhone,
          );
        });
      }
    }
  }

  // ── Date Pickers ──────────────────────────────────────────────────────────

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) setState(() => _dueDate = date);
  }

  Future<void> _pickScheduledDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          _scheduledVisitDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) setState(() => _scheduledVisitDate = date);
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_dueDate == null) {
      AppSnackbar.showError(context, 'Please choose a due date');
      return;
    }

    final assignedTo = ref.read(isAdminProvider)
        ? _selectedAgentId
        : ref.read(authNotifierProvider).valueOrNull?.session.user.id;

    if (assignedTo == null || assignedTo.isEmpty) {
      AppSnackbar.showError(context, 'Please select an agent');
      return;
    }

    if (_selectedDoctor == null) {
      AppSnackbar.showError(context, 'Please select an external doctor');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      String? nullable(TextEditingController c) {
        final value = c.text.trim();
        return value.isEmpty ? null : value;
      }

      await ref.read(followupTasksProvider.notifier).createTask(
            patientId: null,
            assignedTo: assignedTo,
            dueDate: _dueDate!,
            priority: _priority,
            notes: nullable(_notesCtrl),
            targetExtDoctorName: nullable(_docNameCtrl),
            targetExtDoctorHospital: nullable(_docHospitalCtrl),
            targetExtDoctorSpecialization: nullable(_docSpecCtrl),
            targetExtDoctorPhone: nullable(_docPhoneCtrl),
            visitInstructions: nullable(_instructionsCtrl),
            scheduledVisitDate: _scheduledVisitDate,
          );

      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'External doctor visit task created');
      context.pop(true);
    } catch (error) {
      if (!mounted) return;
      AppSnackbar.showError(context, AppError.getMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final agentsAsync = ref.watch(agentsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text(
          'Assign External Doctor Visit',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.doctorAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.doctorAccent.withValues(alpha: 0.2),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      AppIcons.info_outline_rounded,
                      color: AppTheme.doctorAccent,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Assign an agent to visit an external doctor. No patient selection is needed for this task.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: AppTheme.doctorAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── SECTION 1: External Doctor ────────────────────────────────
              const SectionTitle(
                title: 'External Doctor',
                icon: AppIcons.local_hospital_outlined,
              ),
              GestureDetector(
                onTap: _showDoctorPicker,
                child: NeuCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        _selectedDoctor != null
                            ? AppIcons.check_circle_rounded
                            : AppIcons.search_rounded,
                        color: _selectedDoctor != null
                            ? AppTheme.successColor
                            : AppTheme.primaryTeal,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _selectedDoctor != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedDoctor!.name,
                                    style: AppTheme.bodyFont(
                                        size: 14,
                                        weight: FontWeight.w700),
                                  ),
                                  if (_selectedDoctor!.hospital?.isNotEmpty == true ||
                                      _selectedDoctor!.specialization?.isNotEmpty == true)
                                    Text(
                                      [
                                        if (_selectedDoctor!.hospital?.isNotEmpty == true)
                                          _selectedDoctor!.hospital!,
                                        if (_selectedDoctor!.specialization?.isNotEmpty == true)
                                          _selectedDoctor!.specialization!,
                                      ].join(' · '),
                                      style: AppTheme.bodyFont(
                                          size: 12,
                                          color: AppTheme.textMuted),
                                    ),
                                ],
                              )
                            : Text(
                                'Select from directory',
                                style: AppTheme.bodyFont(
                                    size: 14, color: AppTheme.textMuted),
                              ),
                      ),
                      if (_selectedDoctor != null)
                        IconButton(
                          icon: const Icon(AppIcons.clear_rounded,
                              size: 16, color: AppTheme.textMuted),
                          tooltip: 'Clear selection',
                          onPressed: _clearDoctorSelection,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        )
                      else
                        const Icon(AppIcons.arrow_forward_ios_rounded,
                            size: 14, color: AppTheme.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── SECTION 2: Visit Instructions ─────────────────────────────
              const SectionTitle(
                title: 'Visit Instructions',
                icon: AppIcons.assignment_outlined,
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.secondary.withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(AppIcons.info_outline_rounded,
                        color: AppTheme.secondary, size: 16),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "These instructions will appear on the agent's task card as 'Your Mission'",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.secondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              NeuTextField(
                controller: _instructionsCtrl,
                label: 'Instructions for the agent',
                hint:
                    'Bring last 3 months reports. Ask about dosage adjustment. Take note of referral outcome.',
                maxLines: 5,
              ),
              const SizedBox(height: 24),

              // ── SECTION 3: Assignment ─────────────────────────────────────
              const SectionTitle(
                title: 'Assignment',
                icon: AppIcons.assignment_ind_outlined,
              ),
              if (isAdmin)
                agentsAsync.when(
                  data: (agents) => NeuCard(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedAgentId,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      hint: const Text('Select Agent'),
                      items: agents
                          .map((agent) => DropdownMenuItem(
                                value: agent.id,
                                child: Text(agent.fullName),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedAgentId = value),
                    ),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text('Error: $error'),
                )
              else
                NeuCard(
                  child: Row(
                    children: [
                      const Icon(AppIcons.person_outline_rounded,
                          color: AppTheme.primaryTeal),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          ref.watch(authNotifierProvider).valueOrNull
                                  ?.displayName ??
                              'Assigned to you',
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
              const SizedBox(height: 16),

              // Due date
              GestureDetector(
                onTap: _pickDueDate,
                child: NeuCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(AppIcons.calendar_today_rounded,
                          color: AppTheme.primaryTeal, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _dueDate == null
                              ? 'Set Due Date *'
                              : 'Due ${DateFormat('MMM d, yyyy').format(_dueDate!)}',
                          style: TextStyle(
                            fontSize: 16,
                            color: _dueDate == null
                                ? AppTheme.textMuted
                                : AppTheme.textColor,
                            fontWeight: _dueDate == null
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Scheduled visit date (optional)
              GestureDetector(
                onTap: _pickScheduledDate,
                child: NeuCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(AppIcons.event_rounded,
                          color: AppTheme.primaryTeal, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _scheduledVisitDate == null
                              ? 'Scheduled visit date (optional)'
                              : 'Visit ${DateFormat('MMM d, yyyy').format(_scheduledVisitDate!)}',
                          style: TextStyle(
                            fontSize: 15,
                            color: _scheduledVisitDate == null
                                ? AppTheme.textMuted
                                : AppTheme.textColor,
                            fontWeight: _scheduledVisitDate == null
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_scheduledVisitDate != null)
                        IconButton(
                          icon: const Icon(AppIcons.clear_rounded,
                              size: 18, color: AppTheme.textMuted),
                          onPressed: () =>
                              setState(() => _scheduledVisitDate = null),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Priority chips
              NeuCard(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Priority',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Normal'),
                      selected: _priority == 'normal',
                      onSelected: (_) =>
                          setState(() => _priority = 'normal'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Urgent'),
                      selected: _priority == 'urgent',
                      onSelected: (_) =>
                          setState(() => _priority = 'urgent'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── SECTION 4: Internal Notes ─────────────────────────────────
              const SectionTitle(
                title: 'Internal Notes',
                icon: AppIcons.note_alt_rounded,
              ),
              NeuTextField(
                controller: _notesCtrl,
                label: 'Notes (optional)',
                hint: 'Anything else the assistant should know',
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // ── Submit Button ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: NeuButton(
                  onPressed: _saving ? null : _submit,
                  isLoading: _saving,
                  child: const Text(
                    'ASSIGN VISIT TASK',
                    style: TextStyle(
                      color: AppTheme.surfaceWhite,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
