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
import 'package:mediflow/features/followups/followup_provider.dart';
import 'package:mediflow/features/patients/patient_list_provider.dart';

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

  DateTime _visitDate = DateTime.now();
  final _chiefComplaintCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _prescriptionsCtrl = TextEditingController();
  final _visitNotesCtrl = TextEditingController();
  DateTime? _nextFollowupDate;

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

    if (_isEdit) _loadExistingVisit(widget.visitId!);
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
        _meetDrNameCtrl.text = visit.meetDrName ?? '';
        _meetPlaceCtrl.text = visit.meetPlace ?? '';
        _meetDrType = visit.meetDrType;
        _meetTimesVisitedCtrl.text = visit.meetTimesVisited?.toString() ?? '';
        _chiefComplaintCtrl.text = visit.chiefComplaint ?? '';
        _diagnosisCtrl.text = visit.diagnosis ?? '';
        _prescriptionsCtrl.text = visit.prescriptions ?? '';
        _visitNotesCtrl.text = visit.visitNotes ?? '';
        _nextFollowupDate = visit.nextFollowupDate;
      });
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
    } catch (_) {
      // best-effort
    }
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
              meetDrType: _meetDrType,
              meetTimesVisited: int.tryParse(_meetTimesVisitedCtrl.text.trim()),
            );
      } else {
        await ref.read(agentOutsideVisitsProvider.notifier).createVisit(
              patientId: _selectedPatientId,
              followupTaskId: widget.followupTaskId,
              extDoctorName: _extNameCtrl.text.trim(),
              extDoctorSpecialization: _extSpecCtrl.text.trim(),
              extDoctorHospital: _extHospCtrl.text.trim(),
              extDoctorPhone: _extPhoneCtrl.text.trim(),
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
