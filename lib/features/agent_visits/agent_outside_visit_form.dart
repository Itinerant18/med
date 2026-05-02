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
  bool _instructionsLoading = false;

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
  }

  Future<void> _hydrateFromTask(String taskId) async {
    setState(() => _instructionsLoading = true);
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
    } finally {
      if (mounted) setState(() => _instructionsLoading = false);
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

      if (widget.followupTaskId != null) {
        ref.invalidate(followupTasksProvider);
      }
      ref.invalidate(dashboardProvider);
      ref.invalidate(roleAwarePatientsProvider);

      if (mounted) {
        AppSnackbar.showSuccess(context, 'Outside visit recorded successfully');
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
        title: const Text(
          'Record External Doctor Visit',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor's instructions banner — shown only when this form
              // was opened from a follow-up task with instructions attached.
              if (_instructionsLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if ((_instructionsForBanner?.isNotEmpty ?? false))
                _DoctorInstructionsBanner(text: _instructionsForBanner!),

              // Default informational banner (no task context).
              if ((_instructionsForBanner?.isEmpty ?? true) &&
                  !_instructionsLoading)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(AppIcons.info_outline_rounded,
                          color: AppTheme.primaryTeal, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.followupTaskId != null
                              ? 'This will complete the linked follow-up task and record the outside doctor visit.'
                              : 'Record your visit to an external doctor — collecting information, contact details, or outcomes. Link a patient if one was referred by this doctor.',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.primaryTeal),
                        ),
                      ),
                    ],
                  ),
                ),

              // PATIENT SECTION
              // – If the patient is pre-linked (from a task / referral by the
              //   external doctor), display a read-only card.
              // – If standalone (agent visiting for info collection only),
              //   show an informational note — no picker needed.
              const SectionTitle(
                  title: 'Patient', icon: AppIcons.person_search_rounded),
              if (_selectedPatientId != null)
                // Patient pre-linked — show read-only card
                NeuCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(AppIcons.person_rounded,
                            color: AppTheme.primaryTeal, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedPatientName ?? 'Loading...',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const Text(
                              'Referred by this external doctor',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppTheme.primaryTeal, width: 0.8),
                        ),
                        child: const Text(
                          'REFERRED',
                          style: TextStyle(
                            color: AppTheme.primaryTeal,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                // No patient — agent is collecting doctor information only
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.textMuted.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(AppIcons.info_outline_rounded,
                          color: AppTheme.textMuted, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No patient linked — recording external doctor information only. If the doctor refers a patient later, the patient will appear here.',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
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
                  title: 'Specialist Doctor Visited',
                  icon: AppIcons.medical_services_outlined),
              if (isFromTask &&
                  (_extNameCtrl.text.isNotEmpty ||
                      _extSpecCtrl.text.isNotEmpty ||
                      _extHospCtrl.text.isNotEmpty ||
                      _extPhoneCtrl.text.isNotEmpty))
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(AppIcons.info_outline_rounded,
                          color: AppTheme.primaryTeal, size: 14),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pre-filled from your assigned task. Update if different.',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.primaryTeal),
                        ),
                      ),
                    ],
                  ),
                ),
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
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionTitle(
                  title: 'Doctor Meeting Details',
                  icon: AppIcons.medical_services_rounded),
              const Text(
                'If the doctor who actually examined the patient is different from above, fill this in.',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 8),
              NeuCard(
                child: Column(
                  children: [
                    NeuTextField(
                      controller: _meetDrNameCtrl,
                      label: 'Examining Doctor Name',
                      hint: 'Dr. who examined the patient',
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    NeuTextField(
                      controller: _meetPlaceCtrl,
                      label: 'Hospital / Clinic Where Examined',
                      hint: 'Where the meeting took place',
                      textCapitalization: TextCapitalization.words,
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
              const SizedBox(height: 20),
              const SectionTitle(
                  title: 'What Happened at the Visit',
                  icon: AppIcons.medical_information_outlined),
              NeuCard(
                child: Column(
                  children: [
                    NeuTextField(
                      controller: _chiefComplaintCtrl,
                      label: 'Reason for Visit / Patient\'s Complaint',
                      hint: 'Why did the patient see this specialist?',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    NeuTextField(
                      controller: _diagnosisCtrl,
                      label: 'Specialist\'s Diagnosis',
                      hint: 'What did the specialist conclude?',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    NeuTextField(
                      controller: _prescriptionsCtrl,
                      label: 'Medicines / Tests Prescribed',
                      hint: 'What did the specialist prescribe or recommend?',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    NeuTextField(
                      controller: _visitNotesCtrl,
                      label: 'Your Observations',
                      hint: 'Anything important you observed during the visit',
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionTitle(
                  title: 'Specialist Recommended Follow-up',
                  icon: AppIcons.event_repeat_rounded),
              GestureDetector(
                onTap: () => _pickDate(false),
                child: NeuCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(AppIcons.event_repeat_rounded,
                          color: AppTheme.primaryTeal, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _nextFollowupDate == null
                              ? 'Date the specialist said to come back (if any)'
                              : DateFormat('MMMM d, yyyy')
                                  .format(_nextFollowupDate!),
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
                          onPressed: () =>
                              setState(() => _nextFollowupDate = null),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: NeuButton(
                  onPressed: _isLoading ? null : _submit,
                  isLoading: _isLoading,
                  child: Text(
                    isFromTask
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

class _DoctorInstructionsBanner extends StatelessWidget {
  const _DoctorInstructionsBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: AppTheme.warningColor.withValues(alpha: 0.6),
            width: 4,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(AppIcons.assignment_outlined,
              color: AppTheme.warningColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'INSTRUCTIONS FROM DOCTOR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.warningColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textColor,
                    height: 1.4,
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
