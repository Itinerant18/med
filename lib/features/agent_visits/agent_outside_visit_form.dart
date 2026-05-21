// lib/features/agent_visits/agent_outside_visit_form.dart
import 'package:flutter/material.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/agent_visits/agent_outside_visit_provider.dart';
import 'package:mediflow/features/dashboard/dashboard_provider.dart';
import 'package:mediflow/features/staff/external_doctors_provider.dart';
import 'package:mediflow/features/followups/followup_provider.dart';
import 'package:mediflow/features/patients/patient_list_provider.dart';
import 'package:mediflow/features/profile/profile_provider.dart';
import 'package:mediflow/features/work_log/work_log_widget.dart';

/// Predefined list of West Bengal districts for the area dropdown.
const List<String> _westBengalDistricts = [
  'Alipurduar',
  'Bankura',
  'Birbhum',
  'Cooch Behar',
  'Dakshin Dinajpur',
  'Darjeeling',
  'Hooghly',
  'Howrah',
  'Jalpaiguri',
  'Jhargram',
  'Kalimpong',
  'Kolkata',
  'Malda',
  'Murshidabad',
  'Nadia',
  'North 24 Parganas',
  'Paschim Bardhaman',
  'Paschim Medinipur',
  'Purba Bardhaman',
  'Purba Medinipur',
  'Purulia',
  'South 24 Parganas',
  'Uttar Dinajpur',
];

class AgentOutsideVisitForm extends ConsumerStatefulWidget {
  final String? visitId;
  /// Optional: pre-link to an existing followup task. When set, the
  /// form pre-fills external doctor info and shows the doctor's
  /// instructions banner so the assistant has context up front.
  final String? followupTaskId;
  final String? preselectedPatientId;
  final String? preselectedPatientName;

  // Doctor-supplied target external doctor info (typically passed via
  // GoRouter `extra` from the FollowupTaskWidget's "Record Visit" button).
  final String? prefillExtDoctorName;
  final String? prefillExtDoctorHospital;
  final String? prefillExtDoctorSpecialization;
  final String? prefillExtDoctorPhone;
  final String? prefillVisitInstructions;

  const AgentOutsideVisitForm({
    super.key,
    this.visitId,
    this.followupTaskId,
    this.preselectedPatientId,
    this.preselectedPatientName,
    this.prefillExtDoctorName,
    this.prefillExtDoctorHospital,
    this.prefillExtDoctorSpecialization,
    this.prefillExtDoctorPhone,
    this.prefillVisitInstructions,
  });

  @override
  ConsumerState<AgentOutsideVisitForm> createState() =>
      _AgentOutsideVisitFormState();
}

class _AgentOutsideVisitFormState extends ConsumerState<AgentOutsideVisitForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  String? _selectedPatientId;
  String? _selectedPatientName;

  final _extNameCtrl = TextEditingController();
  final _extSpecCtrl = TextEditingController();
  final _extHospCtrl = TextEditingController();
  final _extPhoneCtrl = TextEditingController();
  final _meetDrNameCtrl = TextEditingController();
  final _meetPlaceCtrl = TextEditingController();
  String? _meetDrType;
  final _meetTimesVisitedCtrl = TextEditingController();
  String? _areaDistrict;

  DateTime _visitDate = DateTime.now();
  final _chiefComplaintCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _prescriptionsCtrl = TextEditingController();
  final _visitNotesCtrl = TextEditingController();
  DateTime? _nextFollowupDate;
  DateTime? _originalFollowupDate;
  bool _reminderPreferenceLoaded = false;
  ExternalDoctor? _selectedDoctor;

  // Resolved instructions to show on the info banner. Comes from one of:
  //   1. widget.prefillVisitInstructions (passed via router `extra`)
  //   2. fetched task on init (followupTaskByIdProvider)
  String? _instructionsForBanner;

  bool get _isEdit => widget.visitId != null && widget.visitId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _selectedPatientId = widget.preselectedPatientId;
    _selectedPatientName = widget.preselectedPatientName;
    if (widget.followupTaskId != null && widget.preselectedPatientId != null) {
      assert(_selectedPatientId != null,
          'Patient must be pre-filled when coming from a task');
    }
    _extNameCtrl.text = widget.prefillExtDoctorName ?? '';
    _extHospCtrl.text = widget.prefillExtDoctorHospital ?? '';
    _extSpecCtrl.text = widget.prefillExtDoctorSpecialization ?? '';
    _extPhoneCtrl.text = widget.prefillExtDoctorPhone ?? '';
    _instructionsForBanner =
        widget.prefillVisitInstructions?.trim().isEmpty == true
            ? null
            : widget.prefillVisitInstructions;

    // If we got a followupTaskId but no inline prefill (e.g. opened from a
    // notification), fetch the task once and apply.
    if (widget.followupTaskId != null &&
        widget.prefillExtDoctorName == null &&
        widget.prefillVisitInstructions == null) {
      _hydrateFromTask(widget.followupTaskId!);
    }

    if (_isEdit) {
      _loadExistingVisit(widget.visitId!);
    } else {
      // For new visits, auto-default the follow-up date from agent preference.
      _loadReminderPreference();
    }
  }

  /// Reads the agent's `ext_doc_followup_reminder_days` preference from their
  /// profile and auto-defaults [_nextFollowupDate] so the agent gets a
  /// pre-filled reminder date they can adjust or clear.
  Future<void> _loadReminderPreference() async {
    if (_reminderPreferenceLoaded) return;
    try {
      final profile = await ref.read(profileNotifierProvider.future);
      if (!mounted) return;
      final days = (profile['ext_doc_followup_reminder_days'] as int?) ?? 7;
      setState(() {
        _reminderPreferenceLoaded = true;
        _nextFollowupDate = _visitDate.add(Duration(days: days));
      });
    } catch (_) {
      // Best-effort — if profile fetch fails, leave it unset.
      if (mounted) setState(() => _reminderPreferenceLoaded = true);
    }
  }

  Future<void> _loadExistingVisit(String visitId) async {
    setState(() => _isLoading = true);
    try {
      final visit = await ref.read(agentOutsideVisitByIdProvider(visitId).future);
      if (!mounted || visit == null) return;
      setState(() {
        _selectedPatientId = visit.patientId;
        _selectedPatientName = visit.patientName;
        _visitDate = visit.visitDate;
        _extNameCtrl.text = visit.extDoctorName;
        _extSpecCtrl.text = visit.extDoctorSpecialization ?? '';
        _extHospCtrl.text = visit.extDoctorHospital ?? '';
        _extPhoneCtrl.text = visit.extDoctorPhone ?? '';
        _areaDistrict = visit.areaDistrict;
        _meetDrNameCtrl.text = visit.meetDrName ?? '';
        _meetPlaceCtrl.text = visit.meetPlace ?? '';
        _meetDrType = visit.meetDrType;
        _meetTimesVisitedCtrl.text = visit.meetTimesVisited?.toString() ?? '';
        _chiefComplaintCtrl.text = visit.chiefComplaint ?? '';
        _diagnosisCtrl.text = visit.diagnosis ?? '';
        _prescriptionsCtrl.text = visit.prescriptions ?? '';
        _visitNotesCtrl.text = visit.visitNotes ?? '';
        _nextFollowupDate = visit.nextFollowupDate;
        _originalFollowupDate = visit.nextFollowupDate;
      });
      Future.microtask(_tryMatchDirectoryDoctor);
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, AppError.getMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _hydrateFromTask(String taskId) async {
    try {
      final task = await ref.read(followupTaskByIdProvider(taskId).future);
      if (!mounted || task == null) return;
      setState(() {
        if (_extNameCtrl.text.isEmpty &&
            (task.targetExtDoctorName?.isNotEmpty ?? false)) {
          _extNameCtrl.text = task.targetExtDoctorName!;
        }
        if (_extHospCtrl.text.isEmpty &&
            (task.targetExtDoctorHospital?.isNotEmpty ?? false)) {
          _extHospCtrl.text = task.targetExtDoctorHospital!;
        }
        if (_extSpecCtrl.text.isEmpty &&
            (task.targetExtDoctorSpecialization?.isNotEmpty ?? false)) {
          _extSpecCtrl.text = task.targetExtDoctorSpecialization!;
        }
        if (_extPhoneCtrl.text.isEmpty &&
            (task.targetExtDoctorPhone?.isNotEmpty ?? false)) {
          _extPhoneCtrl.text = task.targetExtDoctorPhone!;
        }
        if (_instructionsForBanner == null &&
            (task.visitInstructions?.isNotEmpty ?? false)) {
          _instructionsForBanner = task.visitInstructions;
        }
        _selectedPatientId ??= task.patientId;
        _selectedPatientName ??= task.patientName;
      });
      Future.microtask(_tryMatchDirectoryDoctor);
    } catch (_) {
      // best-effort
    }
  }

  void _applyDoctorSelection(ExternalDoctor doctor) {
    setState(() {
      _selectedDoctor = doctor;
      _extNameCtrl.text = doctor.name;
      _extSpecCtrl.text = doctor.specialization ?? '';
      _extHospCtrl.text = doctor.hospital ?? '';
      _extPhoneCtrl.text = doctor.phone ?? '';
    });
  }

  void _clearDoctorSelection() {
    setState(() {
      _selectedDoctor = null;
      _extNameCtrl.clear();
      _extSpecCtrl.clear();
      _extHospCtrl.clear();
      _extPhoneCtrl.clear();
    });
  }

  void _tryMatchDirectoryDoctor() {
    if (!mounted) return;
    final name = _extNameCtrl.text.trim().toLowerCase();
    if (name.isEmpty) return;
    final doctors = ref.read(externalDoctorsProvider).valueOrNull;
    if (doctors == null) return;
    try {
      final match = doctors.firstWhere((d) => d.name.toLowerCase() == name);
      if (mounted) setState(() => _selectedDoctor = match);
    } catch (_) {}
  }

  void _showDoctorPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ExternalDoctorPickerSheet(
        onSelected: (doctor) {
          Navigator.of(context).pop();
          _applyDoctorSelection(doctor);
        },
      ),
    );
  }

  @override
  void dispose() {
    _extNameCtrl.dispose();
    _extSpecCtrl.dispose();
    _extHospCtrl.dispose();
    _extPhoneCtrl.dispose();
    _meetDrNameCtrl.dispose();
    _meetPlaceCtrl.dispose();
    _meetTimesVisitedCtrl.dispose();
    _chiefComplaintCtrl.dispose();
    _diagnosisCtrl.dispose();
    _prescriptionsCtrl.dispose();
    _visitNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isVisitDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isVisitDate
          ? _visitDate
          : (_nextFollowupDate ?? DateTime.now().add(const Duration(days: 7))),
      firstDate: isVisitDate
          ? DateTime.now().subtract(const Duration(days: 365))
          : DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isVisitDate) {
        _visitDate = picked;
      } else {
        _nextFollowupDate = picked;
      }
    });
  }

  // Patient picker has been removed from the standalone form.
  // patientId is only populated when pre-filled from a task or referral.

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (_isEdit) {
        await ref.read(agentOutsideVisitsProvider.notifier).updateVisit(
              visitId: widget.visitId!,
              visitDate: _visitDate,
              extDoctorName: _extNameCtrl.text.trim(),
              extDoctorSpecialization: _extSpecCtrl.text.trim(),
              extDoctorHospital: _extHospCtrl.text.trim(),
              extDoctorPhone: _extPhoneCtrl.text.trim(),
              areaDistrict: _areaDistrict,
              meetDrType: _meetDrType,
              meetTimesVisited: int.tryParse(_meetTimesVisitedCtrl.text.trim()),
              chiefComplaint: _chiefComplaintCtrl.text.trim(),
              diagnosis: _diagnosisCtrl.text.trim(),
              prescriptions: _prescriptionsCtrl.text.trim(),
              visitNotes: _visitNotesCtrl.text.trim(),
              nextFollowupDate: _nextFollowupDate,
              scheduleNewTask: _isEdit &&
                  _nextFollowupDate != null &&
                  (_originalFollowupDate == null ||
                      _nextFollowupDate!.year != _originalFollowupDate!.year ||
                      _nextFollowupDate!.month != _originalFollowupDate!.month ||
                      _nextFollowupDate!.day != _originalFollowupDate!.day),
              patientId: _selectedPatientId,
            );
      } else {
        await ref.read(agentOutsideVisitsProvider.notifier).createVisit(
              patientId: _selectedPatientId,
              followupTaskId: widget.followupTaskId,
              extDoctorName: _extNameCtrl.text.trim(),
              extDoctorSpecialization: _extSpecCtrl.text.trim(),
              extDoctorHospital: _extHospCtrl.text.trim(),
              extDoctorPhone: _extPhoneCtrl.text.trim(),
              areaDistrict: _areaDistrict,
              visitDate: _visitDate,
              chiefComplaint: _chiefComplaintCtrl.text.trim(),
              diagnosis: _diagnosisCtrl.text.trim(),
              prescriptions: _prescriptionsCtrl.text.trim(),
              visitNotes: _visitNotesCtrl.text.trim(),
              nextFollowupDate: _nextFollowupDate,
              meetDrName: _meetDrNameCtrl.text.trim().isEmpty
                  ? null
                  : _meetDrNameCtrl.text.trim(),
              meetPlace: _meetPlaceCtrl.text.trim().isEmpty
                  ? null
                  : _meetPlaceCtrl.text.trim(),
              meetDrType: _meetDrType,
              meetTimesVisited: int.tryParse(_meetTimesVisitedCtrl.text.trim()),
            );
      }

      if (!_isEdit && widget.followupTaskId != null) {
        ref.invalidate(followupTasksProvider);
      }
      ref.invalidate(dashboardProvider);
      ref.invalidate(roleAwarePatientsProvider);

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          _isEdit
              ? 'External doctor visit updated successfully'
              : 'Outside visit recorded successfully',
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, AppError.getMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFromTask = widget.followupTaskId != null;

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          _isEdit ? 'Edit External Doctor Visit' : 'Record External Doctor Visit',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                  title: 'Visit Date', icon: AppIcons.calendar_today_rounded),
              GestureDetector(
                onTap: () => _pickDate(true),
                child: NeuCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(AppIcons.calendar_today_rounded,
                          color: AppTheme.primaryTeal, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('MMMM d, yyyy').format(_visitDate),
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppTheme.textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
                                  if (_selectedDoctor!.hospital?.isNotEmpty ==
                                      true)
                                    Text(
                                      _selectedDoctor!.hospital!,
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
              const SizedBox(height: 8),
              NeuCard(
                child: Column(
                  children: [
                    NeuTextField(
                      controller: _extNameCtrl,
                      label: 'Doctor Name *',
                      hint: 'Dr. Full Name',
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    NeuTextField(
                      controller: _extSpecCtrl,
                      label: 'Specialization',
                      hint: 'Cardiology, Orthopedics...',
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    NeuTextField(
                      controller: _extHospCtrl,
                      label: 'Hospital / Clinic',
                      hint: 'Name of the hospital or clinic',
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    NeuTextField(
                      controller: _extPhoneCtrl,
                      label: 'Doctor Phone',
                      hint: 'Contact number',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),

                    // ── Area (District in West Bengal) ──
                    DropdownButtonFormField<String>(
                      initialValue: _areaDistrict,
                      decoration: const InputDecoration(
                        labelText: 'Area (District)',
                        hintText: 'Select district',
                      ),
                      items: _westBengalDistricts
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) => setState(() => _areaDistrict = v),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: _meetDrType,
                      decoration:
                          const InputDecoration(labelText: 'Type of Doctor'),
                      hint: const Text('Select doctor type'),
                      items: [
                        'Dental',
                        'ENT',
                        'General Surgeon',
                        'GP',
                        'RMP',
                        'MDS'
                      ]
                          .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setState(() => _meetDrType = v),
                    ),
                    const SizedBox(height: 12),
                    NeuTextField(
                      controller: _meetTimesVisitedCtrl,
                      label: 'How Many Times Visited This Doctor',
                      hint: 'e.g. 1',
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),

              // ── Visit Outcome ──
              const SizedBox(height: 24),
              const SectionTitle(
                title: 'Visit Outcome',
                icon: AppIcons.note_alt_rounded,
              ),
              NeuCard(
                child: Column(
                  children: [
                    NeuTextField(
                      controller: _chiefComplaintCtrl,
                      label: 'Chief Complaint',
                      hint: "Patient's main complaint during visit",
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    NeuTextField(
                      controller: _diagnosisCtrl,
                      label: 'Diagnosis',
                      hint: 'What the doctor diagnosed',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    NeuTextField(
                      controller: _prescriptionsCtrl,
                      label: 'Prescriptions',
                      hint: 'Medications / treatments prescribed',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    NeuTextField(
                      controller: _visitNotesCtrl,
                      label: 'Visit Notes',
                      hint: 'Any additional notes from the visit',
                      maxLines: 3,
                    ),
                  ],
                ),
              ),

              // ── Follow-up Reminder Section ──
              const SizedBox(height: 24),
              const SectionTitle(
                title: 'Follow-up Reminder',
                icon: AppIcons.notifications_none_rounded,
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
                  child: Row(
                    children: [
                      const Icon(AppIcons.info_outline_rounded,
                          color: AppTheme.secondary, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isEdit 
                            ? 'Change this date to schedule your next visit. Saving will auto-create a new task in "My Tasks".'
                            : 'Set a date to remind yourself to re-visit this doctor. A task will be auto-created in "My Tasks".',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _pickDate(false),
                  child: NeuCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.event_available_rounded,
                          color: _nextFollowupDate != null
                              ? AppTheme.primaryTeal
                              : AppTheme.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _nextFollowupDate == null
                                ? 'No follow-up reminder'
                                : 'Re-visit on ${DateFormat('MMM d, yyyy').format(_nextFollowupDate!)}',
                            style: TextStyle(
                              fontSize: 15,
                              color: _nextFollowupDate == null
                                  ? AppTheme.textMuted
                                  : AppTheme.textColor,
                              fontWeight: _nextFollowupDate == null
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_nextFollowupDate != null)
                          IconButton(
                            icon: const Icon(AppIcons.clear_rounded,
                                size: 18, color: AppTheme.textMuted),
                            tooltip: 'Clear reminder',
                            onPressed: () =>
                                setState(() => _nextFollowupDate = null),
                          ),
                      ],
                    ),
                  ),
                ),

              if (_isEdit) ...[
                const SizedBox(height: 24),
                WorkLogWidget(
                  entityType: 'agent_outside_visit',
                  entityId: widget.visitId!,
                  title: 'Visit Notes',
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: NeuButton(
                  onPressed: _isLoading ? null : _submit,
                  isLoading: _isLoading,
                  child: Text(
                    _isEdit
                        ? 'SAVE CHANGES'
                        : isFromTask
                        ? 'SAVE VISIT & COMPLETE TASK'
                        : 'SAVE EXTERNAL VISIT',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.8,
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

// ─────────────────────────── Picker Sheet ────────────────────────────────────

class _ExternalDoctorPickerSheet extends ConsumerStatefulWidget {
  /// Called with the selected (or newly created) doctor.
  final void Function(ExternalDoctor doctor) onSelected;

  const _ExternalDoctorPickerSheet({required this.onSelected});

  @override
  ConsumerState<_ExternalDoctorPickerSheet> createState() =>
      _ExternalDoctorPickerSheetState();
}

class _ExternalDoctorPickerSheetState
    extends ConsumerState<_ExternalDoctorPickerSheet> {
  // ── search mode ──
  final _searchCtrl = TextEditingController();
  String _query = '';

  // ── add-new mode ──
  bool _isAddingNew = false;
  final _addFormKey = GlobalKey<FormState>();
  final _addNameCtrl = TextEditingController();
  final _addSpecCtrl = TextEditingController();
  final _addHospCtrl = TextEditingController();
  final _addPhoneCtrl = TextEditingController();
  final _addEmailCtrl = TextEditingController();
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _addNameCtrl.dispose();
    _addSpecCtrl.dispose();
    _addHospCtrl.dispose();
    _addPhoneCtrl.dispose();
    _addEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNewDoctor() async {
    if (!(_addFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await ref.read(externalDoctorsProvider.notifier).add(
            name: _addNameCtrl.text.trim(),
            specialization: _addSpecCtrl.text.trim(),
            hospital: _addHospCtrl.text.trim(),
            phone: _addPhoneCtrl.text.trim(),
            email: _addEmailCtrl.text.trim(),
          );
      // Find the newly added doctor in the refreshed list and pass it back.
      final doctors = ref.read(externalDoctorsProvider).valueOrNull ?? [];
      final nameLower = _addNameCtrl.text.trim().toLowerCase();
      ExternalDoctor? added;
      try {
        added = doctors.firstWhere((d) => d.name.toLowerCase() == nameLower);
      } catch (_) {
        // Fallback: build a transient object so the visit form still fills.
        added = ExternalDoctor(
          id: 'new_${DateTime.now().millisecondsSinceEpoch}',
          name: _addNameCtrl.text.trim(),
          specialization: _addSpecCtrl.text.trim().isEmpty
              ? null
              : _addSpecCtrl.text.trim(),
          hospital:
              _addHospCtrl.text.trim().isEmpty ? null : _addHospCtrl.text.trim(),
          phone:
              _addPhoneCtrl.text.trim().isEmpty ? null : _addPhoneCtrl.text.trim(),
        );
      }
      if (mounted) widget.onSelected(added);
    } catch (e) {
      if (mounted) setState(() => _saveError = AppError.getMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _isAddingNew ? 0.75 : 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // ── Handle bar ──
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ── Header ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (_isAddingNew)
                    IconButton(
                      icon: const Icon(AppIcons.arrow_back_ios_rounded,
                          size: 16, color: AppTheme.textMuted),
                      tooltip: 'Back to search',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() {
                        _isAddingNew = false;
                        _saveError = null;
                      }),
                    ),
                  if (_isAddingNew) const SizedBox(width: 8),
                  Text(
                    _isAddingNew ? 'Add New Doctor' : 'Select External Doctor',
                    style:
                        AppTheme.bodyFont(size: 16, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── Body ──
            Expanded(
              child: _isAddingNew
                  ? _buildAddForm(scrollController)
                  : _buildSearchList(scrollController),
            ),
            // ── Fixed footer: "Add new doctor" button (search mode only) ──
            if (!_isAddingNew)
              SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _isAddingNew = true),
                      icon: const Icon(AppIcons.add_rounded, size: 16),
                      label: const Text('Add new doctor to directory'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryTeal,
                        side: const BorderSide(color: AppTheme.primaryTeal),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSearchList(ScrollController scrollController) {
    final directoryAsync = ref.watch(externalDoctorsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search by name or hospital...',
              prefixIcon: const Icon(AppIcons.search_rounded, size: 16),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(AppIcons.clear_rounded, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) =>
                setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: directoryAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load directory.\nYou can still add a new doctor below.',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyFont(
                      size: 13, color: AppTheme.textMuted),
                ),
              ),
            ),
            data: (doctors) {
              final filtered = _query.isEmpty
                  ? doctors
                  : doctors
                      .where((d) =>
                          d.name.toLowerCase().contains(_query) ||
                          (d.hospital
                                  ?.toLowerCase()
                                  .contains(_query) ??
                              false))
                      .toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _query.isEmpty
                          ? 'No doctors in directory yet.\nUse the button below to add one.'
                          : 'No match for "$_query".\nUse the button below to add them.',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyFont(
                          size: 13, color: AppTheme.textMuted),
                    ),
                  ),
                );
              }

              return ListView.builder(
                controller: scrollController,
                itemCount: filtered.length,
                itemBuilder: (context, index) => _DoctorPickerTile(
                  doctor: filtered[index],
                  onTap: () => widget.onSelected(filtered[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddForm(ScrollController scrollController) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _addFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NeuTextField(
              controller: _addNameCtrl,
              label: 'Doctor Name *',
              hint: 'Dr. Full Name',
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            NeuTextField(
              controller: _addSpecCtrl,
              label: 'Specialization',
              hint: 'e.g. Cardiology, Orthopedics',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            NeuTextField(
              controller: _addHospCtrl,
              label: 'Hospital / Clinic',
              hint: 'Hospital or clinic name',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            NeuTextField(
              controller: _addPhoneCtrl,
              label: 'Phone',
              hint: 'Contact number',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            NeuTextField(
              controller: _addEmailCtrl,
              label: 'Email',
              hint: 'Email address',
              keyboardType: TextInputType.emailAddress,
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.errorColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(AppIcons.error_outline_rounded,
                        color: AppTheme.errorColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _saveError!,
                        style: AppTheme.bodyFont(
                            size: 13, color: AppTheme.errorColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: NeuButton(
                onPressed: _saving ? null : _saveNewDoctor,
                isLoading: _saving,
                child: const Text('Save & Select'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorPickerTile extends StatelessWidget {
  final ExternalDoctor doctor;
  final VoidCallback onTap;

  const _DoctorPickerTile({required this.doctor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.12),
        child: const Icon(AppIcons.local_hospital_outlined,
            size: 16, color: AppTheme.primaryTeal),
      ),
      title: Text(
        doctor.name,
        style: AppTheme.bodyFont(size: 14, weight: FontWeight.w600),
      ),
      subtitle: (doctor.specialization?.isNotEmpty == true ||
              doctor.hospital?.isNotEmpty == true)
          ? Text(
              [
                if (doctor.specialization?.isNotEmpty == true)
                  doctor.specialization!,
                if (doctor.hospital?.isNotEmpty == true) doctor.hospital!,
              ].join(' · '),
              style: AppTheme.bodyFont(size: 12, color: AppTheme.textMuted),
            )
          : null,
      trailing: doctor.fromHistory
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'From visits',
                style: AppTheme.bodyFont(
                    size: 10, color: AppTheme.infoColor),
              ),
            )
          : null,
    );
  }
}
