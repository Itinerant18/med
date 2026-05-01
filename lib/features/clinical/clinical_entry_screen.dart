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
  bool _testsPerformed = false;
  bool _otRequired = false;
  String _flowStatus = 'Admitted';

  // Clinical notes
  final _diagnosisController = TextEditingController();
  final _prescriptionsController = TextEditingController();
  final _handoffController = TextEditingController();

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
    if (widget.patientId != null) {
      _selectedPatientId = widget.patientId;
      _selectedPatientName = widget.patientName;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadPatientInfo();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(patientSearchQueryProvider.notifier).state = '';
          _searchController.clear();
        }
      });
    }
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
    _bpSystolicController.dispose();
    _bpDiastolicController.dispose();
    _pulseController.dispose();
    _tempController.dispose();
    _spo2Controller.dispose();
    _rrController.dispose();
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
      });
    } catch (e) {
      debugPrint('Failed to load patient info: $e');
    }
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

    final doctorName = user.userMetadata?['full_name'] ?? 'Unknown';
    final now = DateTime.now().toIso8601String();

    final visitData = <String, dynamic>{
      'patient_id': _selectedPatientId,
      'doctor_id': user.id,
      'visit_type': _visitType,
      'chief_complaint': _chiefComplaint,
      'tests_performed': _testsPerformed,
      'ot_required': _otRequired,
      'patient_flow_status': _flowStatus,
      'final_diagnosis': _diagnosisController.text.trim(),
      'prescriptions': _prescriptionsController.text.trim(),
      'staff_comments': _handoffController.text.trim(),
      'last_updated_by': doctorName,
      'last_updated_at': now,
      'visit_date': now,
    };

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
      }
      _chiefComplaint = null;
      _isOtherComplaint = false;
      _testsPerformed = false;
      _otRequired = false;
      _flowStatus = 'Admitted';
      _visitType = 'OPD';
    });
    _customComplaintController.clear();
    _diagnosisController.clear();
    _prescriptionsController.clear();
    _handoffController.clear();
    _bpSystolicController.clear();
    _bpDiastolicController.clear();
    _pulseController.clear();
    _tempController.clear();
    _spo2Controller.clear();
    _rrController.clear();
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
                  _buildPatientSelector(),
                  const SizedBox(height: 16),
                  _buildVisitDetailsSection(),
                  const SizedBox(height: 16),
                  _buildVitalsSection(),
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
                        ref.read(patientSearchQueryProvider.notifier).state =
                            '';
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

  Widget _buildVitalsSection() {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
              title: 'Vitals', icon: AppIcons.monitor_heart_rounded),
          Row(
            children: [
              Expanded(
                child: NeuTextField(
                  controller: _bpSystolicController,
                  label: 'BP Systolic',
                  hint: '120',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NeuTextField(
                  controller: _bpDiastolicController,
                  label: 'BP Diastolic',
                  hint: '80',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: NeuTextField(
                  controller: _pulseController,
                  label: 'Pulse (bpm)',
                  hint: '72',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NeuTextField(
                  controller: _tempController,
                  label: 'Temp (°C)',
                  hint: '37.0',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: NeuTextField(
                  controller: _spo2Controller,
                  label: 'SpO2 (%)',
                  hint: '98',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NeuTextField(
                  controller: _rrController,
                  label: 'Resp. Rate',
                  hint: '16',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
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
          _buildSwitchRow(
            label: 'Tests Performed',
            value: _testsPerformed,
            activeColor: const Color(0xFF38A169),
            statusText: _testsPerformed ? 'Done' : 'Not performed',
            onChanged: (val) => setState(() => _testsPerformed = val),
          ),
          const Divider(height: 24),
          _buildSwitchRow(
            label: 'OT Required',
            value: _otRequired,
            activeColor: const Color(0xFFE53E3E),
            statusText: _otRequired ? 'Scheduled' : 'Not required',
            onChanged: (val) => setState(() => _otRequired = val),
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
            controller: _prescriptionsController,
            label: 'Prescriptions',
            hint: 'Medication, dosage, duration...',
            maxLines: 4,
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
