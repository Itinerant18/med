// lib/features/clinical/clinical_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/features/clinical/clinical_provider.dart';
import 'package:mediflow/features/patients/patient_provider.dart';

class ClinicalEntryScreen extends ConsumerStatefulWidget {
  final String? patientId;
  final String? patientName;
  const ClinicalEntryScreen({
    super.key,
    this.patientId,
    this.patientName,
  });

  @override
  ConsumerState<ClinicalEntryScreen> createState() =>
      _ClinicalEntryScreenState();
}

class _ClinicalEntryScreenState extends ConsumerState<ClinicalEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();

  // Patient selection
  String? _selectedPatientId;
  String? _selectedPatientName;
  String? _selectedPatientAge;

  // Visit details
  String _visitType = 'OPD';
  String? _chiefComplaint;
  bool _isOtherComplaint = false;
  final _customComplaintController = TextEditingController();

  // Operational tracking
  bool _otRequired = false;
  String _flowStatus = 'Admitted';

  // Canonical test list — kept in sync with patient_form_screen.dart.
  static const List<String> _canonicalTests = [
    'Blood Test',
    'CT Scan',
    'MRI',
    'HRCT Thorax',
    'Biopsy Report',
    'Other',
  ];

  // Granular investigation status (populated from patient record).
  // Always contains every canonical test once a patient is loaded.
  Map<String, dynamic> _investigationStatus = {};

  // OT details revealed when _otRequired is true
  final _otTypeController = TextEditingController();
  final _otScheduledDateController = TextEditingController();
  DateTime? _scheduledOtDate;

  // Assigned-checkup context (Task 4)
  String? _patientServiceStatus;
  String? _patientAssignedDoctorId;

  // Clinical notes
  final _diagnosisController = TextEditingController();
  final _prescriptionsController = TextEditingController();
  final _handoffController = TextEditingController();
  final _postOpReferredToController = TextEditingController();

  // Vitals
  final _bpSystolicController = TextEditingController();
  final _bpDiastolicController = TextEditingController();
  final _pulseController = TextEditingController();
  final _tempController = TextEditingController();
  final _spo2Controller = TextEditingController();
  final _rrController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-populate the investigation map with all canonical tests so the
    // checklist is always visible, even before a patient is selected.
    _investigationStatus = _mergeWithCanonical({});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(patientSearchQueryProvider.notifier).state = '';
      _searchController.clear();
      if (widget.patientId != null) {
        _selectedPatientId = widget.patientId;
        _selectedPatientName = widget.patientName;
        _loadPatientInfo();
      }
    });
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customComplaintController.dispose();
    _diagnosisController.dispose();
    _prescriptionsController.dispose();
    _handoffController.dispose();
    _postOpReferredToController.dispose();
    _bpSystolicController.dispose();
    _bpDiastolicController.dispose();
    _pulseController.dispose();
    _tempController.dispose();
    _spo2Controller.dispose();
    _rrController.dispose();
    _otTypeController.dispose();
    _otScheduledDateController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientInfo() async {
    if (_selectedPatientId == null) return;
    try {
      final patient =
          await ref.read(patientDetailProvider(_selectedPatientId!).future);
      if (!mounted || patient == null) return;
      setState(() {
        _selectedPatientName = patient.fullName;
        final dob = patient.dateOfBirth;
        _selectedPatientAge =
            dob != null ? (DateTime.now().year - dob.year).toString() : 'N/A';
        _investigationStatus =
            _mergeWithCanonical(patient.investigationStatus);
        _patientServiceStatus = patient.serviceStatus;
        _patientAssignedDoctorId = patient.assignedDoctorId;
      });
    } catch (e) {
      debugPrint('Failed to load patient info: $e');
    }
  }

  /// Builds an investigation map that contains every canonical test.
  /// Existing patient values are preserved as-is when they are 'done';
  /// 'na' and any missing entries are normalized to 'pending' so the
  /// clinical entry is strictly binary (done / not done).
  static Map<String, dynamic> _mergeWithCanonical(
      Map<String, dynamic> existing) {
    return {
      for (final test in _canonicalTests)
        test: existing[test]?.toString().toLowerCase() == 'done'
            ? 'done'
            : 'pending',
    };
  }

  Future<void> _onCompleteVisit() async {
    if (_selectedPatientId == null) {
      AppSnackbar.showError(context, 'Please select a patient first.');
      return;
    }
    if (_chiefComplaint == null) {
      AppSnackbar.showError(context, 'Please select a chief complaint.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      AppSnackbar.showError(context, 'Session expired. Please log in again.');
      return;
    }

    // ── OT / flow-status conflict guard ──────────────────────────────────────
    // A patient cannot be both Discharged/Referred AND scheduled for surgery.
    if (_otRequired &&
        (_flowStatus == 'Discharged' || _flowStatus == 'Referred')) {
      AppSnackbar.showError(
        context,
        'Cannot schedule OT for a ${_flowStatus.toLowerCase()} patient. '
        'Disable "OT Required" or change the Patient Flow Status.',
      );
      return;
    }

    final doctorName = user.userMetadata?['full_name'] ?? 'Unknown';
    final now = DateTime.now().toIso8601String();

    // Derive tests_performed: true only when every canonical test is 'done'.
    final allTestsDone = _investigationStatus.values
        .every((v) => v?.toString().toLowerCase() == 'done');

    // Checkup flag: only set when pre-loaded patient is an assigned checkup.
    final isAssignedCheckup = widget.patientId != null &&
        _patientServiceStatus?.toLowerCase() == 'pending_checkup' &&
        _patientAssignedDoctorId == user.id;

    final visitData = <String, dynamic>{
      'patient_id': _selectedPatientId,
      'doctor_id': user.id,
      'visit_type': _visitType,
      'chief_complaint': _chiefComplaint,
      'tests_performed': allTestsDone,
      'ot_required': _otRequired,
      'patient_flow_status': _flowStatus,
      'final_diagnosis': _diagnosisController.text.trim(),
      'post_op_referred_to': _postOpReferredToController.text.trim(),
      'staff_comments': _handoffController.text.trim(),
      'last_updated_by': doctorName,
      'last_updated_at': now,
      'visit_date': now,
      'is_assigned_checkup': isAssignedCheckup,
    };

    // Always send the full investigation_status map so the visits row is the
    // authoritative record of which tests were performed (or that none were
    // defined). An empty map is a valid and meaningful value here.
    visitData['investigation_status'] = _investigationStatus;

    if (_otRequired && _otTypeController.text.trim().isNotEmpty) {
      visitData['ot_type'] = _otTypeController.text.trim();
    }
    if (_otRequired && _scheduledOtDate != null) {
      visitData['ot_scheduled_date'] = _scheduledOtDate!.toIso8601String();
    }

    if (_isOtherComplaint && _customComplaintController.text.isNotEmpty) {
      visitData['chief_complaint_custom'] =
          _customComplaintController.text.trim();
    }
    if (_bpSystolicController.text.isNotEmpty) {
      visitData['bp_systolic'] = int.tryParse(_bpSystolicController.text);
    }
    if (_bpDiastolicController.text.isNotEmpty) {
      visitData['bp_diastolic'] = int.tryParse(_bpDiastolicController.text);
    }
    if (_pulseController.text.isNotEmpty) {
      visitData['pulse'] = int.tryParse(_pulseController.text);
    }
    if (_tempController.text.isNotEmpty) {
      visitData['temperature'] = double.tryParse(_tempController.text);
    }
    if (_spo2Controller.text.isNotEmpty) {
      visitData['spo2'] = int.tryParse(_spo2Controller.text);
    }
    if (_rrController.text.isNotEmpty) {
      visitData['respiratory_rate'] = int.tryParse(_rrController.text);
    }

    await ref.read(clinicalNotifierProvider.notifier).saveVisit(visitData);

    if (!mounted) return;

    final state = ref.read(clinicalNotifierProvider);
    if (state.hasError) {
      AppSnackbar.showError(context, AppError.getMessage(state.error));
    } else {
      AppSnackbar.showSuccess(context, 'Visit saved successfully');
      if (widget.patientId != null) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) context.pop();
      } else {
        _resetForm();
      }
    }
  }

  void _resetForm() {
    setState(() {
      if (widget.patientId == null) {
        _selectedPatientId = null;
        _selectedPatientName = null;
        _selectedPatientAge = null;
        _investigationStatus = _mergeWithCanonical({});
        _patientServiceStatus = null;
        _patientAssignedDoctorId = null;
      }
      _chiefComplaint = null;
      _isOtherComplaint = false;
      _otRequired = false;
      _flowStatus = 'Admitted';
      _visitType = 'OPD';
      _scheduledOtDate = null;
    });
    _customComplaintController.clear();
    _diagnosisController.clear();
    _prescriptionsController.clear();
    _handoffController.clear();
    _postOpReferredToController.clear();
    _bpSystolicController.clear();
    _bpDiastolicController.clear();
    _pulseController.clear();
    _tempController.clear();
    _spo2Controller.clear();
    _rrController.clear();
    _otTypeController.clear();
    _otScheduledDateController.clear();
    _searchController.clear();
    ref.read(patientSearchQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final clinicalState = ref.watch(clinicalNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text('Active Service',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildAssignedCheckupBanner(),
                  _buildPatientSelector(),
                  const SizedBox(height: 16),
                  _buildVisitDetailsSection(),
                  const SizedBox(height: 16),
                  _buildOperationalTrackingSection(),
                  const SizedBox(height: 16),
                  _buildClinicalNotesSection(),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: AppTheme.bgColor,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: SafeArea(
                top: false,
                child: NeuButton(
                  onPressed: clinicalState.isLoading ? null : _onCompleteVisit,
                  isLoading: clinicalState.isLoading,
                  color: AppTheme.primaryTeal,
                  child: const Text(
                    'COMPLETE VISIT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientSelector() {
    if (_selectedPatientId != null) {
      return NeuCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(AppIcons.person_rounded,
                  color: AppTheme.primaryTeal, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedPatientName ?? 'Loading...',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  Text(
                    'Age: ${_selectedPatientAge ?? '—'} • ID: ${_selectedPatientId?.substring(0, 8)}...',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            if (widget.patientId == null)
              IconButton(
                icon: const Icon(AppIcons.close_rounded,
                    color: Colors.red, size: 20),
                onPressed: () => setState(() {
                  _selectedPatientId = null;
                  _selectedPatientName = null;
                  _selectedPatientAge = null;
                  _patientServiceStatus = null;
                  _patientAssignedDoctorId = null;
                  _investigationStatus = _mergeWithCanonical({});
                }),
              ),
          ],
        ),
      );
    }

    final searchResults = ref.watch(clinicalPatientSearchProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NeuTextField(
          controller: _searchController,
          label: 'Search Patient',
          hint: 'Type at least 2 characters...',
          prefixIcon: const Icon(AppIcons.search_rounded,
              color: AppTheme.primaryTeal, size: 18),
          onChanged: (val) =>
              ref.read(patientSearchQueryProvider.notifier).state = val,
        ),
        searchResults.when(
          data: (results) {
            if (results.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: AppTheme.bgColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.white,
                      offset: Offset(-2, -2),
                      blurRadius: 6),
                  BoxShadow(
                      color: Color(0xFFA3B1C6),
                      offset: Offset(2, 2),
                      blurRadius: 6),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  children: results.map((p) {
                    final dob = p['date_of_birth'] != null
                        ? DateTime.tryParse(p['date_of_birth'])
                        : null;
                    final age = dob != null
                        ? (DateTime.now().year - dob.year).toString()
                        : '—';
                    return ListTile(
                      dense: true,
                      leading: const CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.primaryTeal,
                        child: Icon(AppIcons.person_rounded,
                            size: 16, color: Colors.white),
                      ),
                      title: Text(p['full_name'],
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('Age: $age years',
                          style: const TextStyle(fontSize: 11)),
                      onTap: () {
                        setState(() {
                          _selectedPatientId = p['id'];
                          _selectedPatientName = p['full_name'];
                          _selectedPatientAge = age;
                        });
                        _searchController.clear();
                        ref.read(patientSearchQueryProvider.notifier).state = '';
                        // Load full patient data so investigation statuses,
                        // service status, and assigned-doctor context are
                        // populated from the DB — this was the missing call
                        // that made the search feel "broken" after selection.
                        _loadPatientInfo();
                      },
                    );
                  }).toList(),
                ),
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(
                color: AppTheme.primaryTeal, backgroundColor: AppTheme.bgColor),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildVisitDetailsSection() {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
              title: 'Visit Details', icon: AppIcons.calendar_today_rounded),
          DropdownButtonFormField<String>(
            initialValue: _visitType,
            decoration: const InputDecoration(labelText: 'Visit Type'),
            items: ['OPD', 'IPD', 'Emergency']
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (val) => setState(() => _visitType = val!),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _chiefComplaint,
            decoration: const InputDecoration(labelText: 'Chief Complaint *'),
            hint: const Text('Select complaint'),
            items: [
              'Fever',
              'Pain',
              'Injury',
              'Respiratory',
              'Post-Op',
              'Follow-up',
              'Other'
            ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) => setState(() {
              _chiefComplaint = val;
              _isOtherComplaint = val == 'Other';
            }),
            validator: (val) =>
                val == null ? 'Please select a chief complaint' : null,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: _isOtherComplaint
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: NeuTextField(
                      controller: _customComplaintController,
                      label: 'Describe Complaint',
                      hint: 'Specific details...',
                      maxLines: 2,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please describe the complaint'
                          : null,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalTrackingSection() {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
              title: 'Operational Tracking',
              icon: AppIcons.track_changes_rounded),
          // ── Tests: master "All Tests Done" toggle + per-test checklist ──────
          // _investigationStatus is always pre-populated with the canonical
          // test list (done / pending). Master switch marks all at once;
          // individual switches override specific tests.
          _buildSwitchRow(
            label: 'All Tests Done',
            value: _investigationStatus.values
                .every((v) => v?.toString().toLowerCase() == 'done'),
            activeColor: const Color(0xFF38A169),
            statusText: _investigationStatus.values
                    .every((v) => v?.toString().toLowerCase() == 'done')
                ? 'All complete'
                : 'In progress',
            onChanged: (val) => setState(() {
              for (final key in _investigationStatus.keys) {
                _investigationStatus[key] = val ? 'done' : 'pending';
              }
            }),
          ),
          const Divider(height: 20),
          const Text(
            'Investigations',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ..._investigationStatus.entries.map((entry) {
            final isDone = entry.value?.toString().toLowerCase() == 'done';
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        isDone ? 'Done' : 'Pending',
                        style: TextStyle(
                          color: isDone
                              ? const Color(0xFF38A169)
                              : AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: isDone,
                    activeTrackColor:
                        const Color(0xFF38A169).withValues(alpha: 0.3),
                    activeThumbColor: const Color(0xFF38A169),
                    onChanged: (val) => setState(() {
                      _investigationStatus[entry.key] =
                          val ? 'done' : 'pending';
                    }),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 24),
          // ── OT Required with animated reveal ──────────────────────────────
          _buildSwitchRow(
            label: 'OT Required',
            value: _otRequired,
            activeColor: const Color(0xFFE53E3E),
            statusText: _otRequired ? 'Scheduled' : 'Not required',
            onChanged: (val) {
              setState(() {
                _otRequired = val;
                // Clear OT detail fields when the switch is toggled off so
                // stale data is never accidentally included in the payload.
                if (!val) {
                  _otTypeController.clear();
                  _otScheduledDateController.clear();
                  _scheduledOtDate = null;
                }
              });
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _otRequired
                ? Column(
                    children: [
                      const SizedBox(height: 14),
                      NeuTextField(
                        controller: _otTypeController,
                        label: 'OT Type',
                        hint: 'e.g. General, Laparoscopic, Ortho...',
                      ),
                      const SizedBox(height: 12),
                      NeuTextField(
                        controller: _otScheduledDateController,
                        label: 'Scheduled Date',
                        hint: 'Tap to select a date',
                        readOnly: true,
                        onTap: () => _pickOtDate(context),
                        suffixIcon: const Icon(
                            AppIcons.calendar_today_rounded,
                            size: 16,
                            color: AppTheme.primaryTeal),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _flowStatus,
            decoration: const InputDecoration(labelText: 'Patient Flow Status'),
            items: ['Admitted', 'Under Observation', 'Discharged', 'Referred']
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (val) => setState(() => _flowStatus = val!),
          ),
        ],
      ),
    );
  }

  Future<void> _pickOtDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledOtDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primaryTeal),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _scheduledOtDate = picked;
        _otScheduledDateController.text =
            '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  Widget _buildAssignedCheckupBanner() {
    final user = Supabase.instance.client.auth.currentUser;
    final show = widget.patientId != null &&
        _patientServiceStatus?.toLowerCase() == 'pending_checkup' &&
        _patientAssignedDoctorId != null &&
        _patientAssignedDoctorId == user?.id;
    if (!show) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.35)),
      ),
      child: const Row(
        children: [
          Icon(AppIcons.warning_amber_rounded,
              color: AppTheme.warningColor, size: 16),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Assigned Checkup — Complete this visit to notify the Head Doctor.',
              style: TextStyle(
                color: AppTheme.warningColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalNotesSection() {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
              title: 'Clinical Notes', icon: AppIcons.note_alt_rounded),
          NeuTextField(
            controller: _diagnosisController,
            label: 'Final Diagnosis',
            hint: 'Enter diagnosis...',
            maxLines: 3,
          ),
          const SizedBox(height: 14),
          NeuTextField(
            controller: _postOpReferredToController,
            label: 'Post Op Refered To (Radiation Oncology) :',
            hint: 'Enter details...',
            maxLines: 2,
          ),
          const SizedBox(height: 14),
          NeuTextField(
            controller: _handoffController,
            label: 'Staff Handoff Notes',
            hint: 'Notes for next shift...',
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required bool value,
    required Color activeColor,
    required String statusText,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 2),
            Text(
              statusText,
              style: TextStyle(
                color: value ? activeColor : AppTheme.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        Switch(
          value: value,
          activeTrackColor: activeColor.withValues(alpha: 0.3),
          activeThumbColor: activeColor,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
