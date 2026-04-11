// lib/features/clinical/clinical_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/features/clinical/clinical_provider.dart';
import 'package:mediflow/features/patients/patient_provider.dart';

class ClinicalEntryScreen extends ConsumerStatefulWidget {
  final String? patientId;
  const ClinicalEntryScreen({super.key, this.patientId});

  @override
  ConsumerState<ClinicalEntryScreen> createState() => _ClinicalEntryScreenState();
}

class _ClinicalEntryScreenState extends ConsumerState<ClinicalEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Selection State
  String? _selectedPatientId;
  String? _selectedPatientName;
  String? _selectedPatientAge;

  // Visit Details
  String _visitType = 'OPD';
  String? _chiefComplaint;
  bool _isOtherComplaint = false;
  final _customComplaintController = TextEditingController();

  // Operational Tracking
  bool _testsPerformed = false;
  bool _otRequired = false;
  String _flowStatus = 'Admitted';

  // Notes
  final _diagnosisController = TextEditingController();
  final _prescriptionsController = TextEditingController();
  final _handoffController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.patientId != null) {
      _selectedPatientId = widget.patientId;
      _loadPatientInfo();
    }
  }

  Future<void> _loadPatientInfo() async {
    if (_selectedPatientId == null) return;
    try {
      final patient = await ref.read(patientDetailProvider(_selectedPatientId!).future);
      if (patient != null && mounted) {
        setState(() {
          _selectedPatientName = patient['full_name'];
          if (patient['date_of_birth'] != null) {
            final dob = DateTime.parse(patient['date_of_birth']);
            _selectedPatientAge = (DateTime.now().year - dob.year).toString();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _onCompleteVisit() async {
    if (_selectedPatientId == null) {
      AppSnackbar.showError(context, 'Please select a patient first.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final doctorName = user.userMetadata?['full_name'] ?? 'Unknown';
    final now = DateTime.now().toIso8601String();

    final visitData = {
      'patient_id': _selectedPatientId,
      'doctor_id': user.id,
      'visit_type': _visitType,
      'chief_complaint': _chiefComplaint,
      'chief_complaint_custom': _isOtherComplaint ? _customComplaintController.text : null,
      'tests_performed': _testsPerformed,
      'ot_required': _otRequired,
      'patient_flow_status': _flowStatus,
      'final_diagnosis': _diagnosisController.text,
      'prescriptions': _prescriptionsController.text,
      'staff_comments': _handoffController.text,
      'last_updated_by': doctorName,
      'last_updated_at': now,
      'visit_date': now,
    };

    await ref.read(clinicalNotifierProvider.notifier).saveVisit(visitData);

    if (!mounted) return;

    final state = ref.read(clinicalNotifierProvider);
    if (state.hasError) {
      AppSnackbar.showError(context, AppError.getMessage(state.error));
    } else {
      AppSnackbar.showSuccess(context, 'Visit saved successfully');
      _resetForm();
    }
  }

  void _resetForm() {
    setState(() {
      if (widget.patientId == null) {
        _selectedPatientId = null;
        _selectedPatientName = null;
        _selectedPatientAge = null;
      }
      _customComplaintController.clear();
      _diagnosisController.clear();
      _prescriptionsController.clear();
      _handoffController.clear();
      _testsPerformed = false;
      _otRequired = false;
      _chiefComplaint = null;
      _isOtherComplaint = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final clinicalState = ref.watch(clinicalNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text('Active Service', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildPatientSelector(),
              const SizedBox(height: 20),
              _buildVisitDetailsSection(),
              const SizedBox(height: 20),
              _buildOperationalTrackingSection(),
              const SizedBox(height: 20),
              _buildClinicalNotesSection(),
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        color: AppTheme.bgColor,
        padding: const EdgeInsets.all(16),
        child: NeuButton(
          onPressed: _onCompleteVisit,
          isLoading: clinicalState.isLoading,
          color: AppTheme.primaryTeal,
          child: const Text(
            'COMPLETE VISIT',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientSelector() {
    if (_selectedPatientId != null) {
      return NeuCard(
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppTheme.primaryTeal,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedPatientName ?? 'Loading...',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'Age: ${_selectedPatientAge ?? '??'} • ID: ${_selectedPatientId?.substring(0, 8)}...',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (widget.patientId == null)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => setState(() => _selectedPatientId = null),
              ),
          ],
        ),
      );
    }

    final searchResults = ref.watch(filteredPatientsProvider);

    return Column(
      children: [
        NeuTextField(
          label: 'Search Patient',
          hint: 'Enter name...',
          onChanged: (val) => ref.read(patientSearchQueryProvider.notifier).state = val,
        ),
        if (searchResults.hasValue && searchResults.value!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: AppTheme.bgColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: AppTheme.darkShadow, offset: Offset(2, 2), blurRadius: 5),
              ],
            ),
            child: Column(
              children: searchResults.value!.map((p) => ListTile(
                title: Text(p['full_name']),
                subtitle: Text('ID: ${p['id'].toString().substring(0, 8)}'),
                onTap: () {
                  setState(() {
                    _selectedPatientId = p['id'];
                    _selectedPatientName = p['full_name'];
                    final dob = p['date_of_birth'] != null ? DateTime.parse(p['date_of_birth']) : null;
                    _selectedPatientAge = dob != null ? (DateTime.now().year - dob.year).toString() : '??';
                  });
                },
              )).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildVisitDetailsSection() {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Visit Details'),
          DropdownButtonFormField<String>(
            initialValue: _visitType,
            decoration: const InputDecoration(labelText: 'Visit Type'),
            items: ['OPD', 'IPD', 'Emergency'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (val) => setState(() => _visitType = val!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _chiefComplaint,
            decoration: const InputDecoration(labelText: 'Chief Complaint'),
            items: ['Fever', 'Pain', 'Injury', 'Respiratory', 'Post-Op', 'Follow-up', 'Other']
                .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) => setState(() {
              _chiefComplaint = val;
              _isOtherComplaint = val == 'Other';
            }),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: _isOtherComplaint
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: NeuTextField(
                      controller: _customComplaintController,
                      label: 'Describe complaint',
                      hint: 'Specific details...',
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
          _buildSectionTitle('Operational Tracking'),
          _buildSwitchRow(
            label: 'Tests Performed?',
            value: _testsPerformed,
            activeThumbColor: const Color(0xFF38A169),
            statusText: _testsPerformed ? 'Done' : 'Pending',
            onChanged: (val) => setState(() => _testsPerformed = val),
          ),
          const Divider(height: 32),
          _buildSwitchRow(
            label: 'OT Required?',
            value: _otRequired,
            activeThumbColor: const Color(0xFFE53E3E),
            statusText: _otRequired ? 'Scheduled' : 'Not Required',
            onChanged: (val) => setState(() => _otRequired = val),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _flowStatus,
            decoration: const InputDecoration(labelText: 'Patient Flow Status'),
            items: ['Admitted', 'Under Observation', 'Discharged', 'Referred']
                .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
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
          _buildSectionTitle('Clinical Notes'),
          NeuTextField(
            controller: _diagnosisController,
            label: 'Final Diagnosis',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          NeuTextField(
            controller: _prescriptionsController,
            label: 'Prescriptions',
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          NeuTextField(
            controller: _handoffController,
            label: 'Staff Handoff Notes',
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF718096),
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required bool value,
    required Color activeThumbColor,
    required String statusText,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              statusText,
              style: TextStyle(color: activeThumbColor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
        Switch(
          value: value,
          activeThumbColor: activeThumbColor,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
