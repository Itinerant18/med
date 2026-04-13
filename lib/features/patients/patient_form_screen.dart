import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/patients/patient_provider.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/features/patients/document_upload_widget.dart';

class PatientFormScreen extends ConsumerStatefulWidget {
  final String? patientId;
  const PatientFormScreen({super.key, this.patientId});

  @override
  ConsumerState<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends ConsumerState<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isInit = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _occupationController = TextEditingController();
  final _schemeOtherController = TextEditingController();
  final _symptomsController = TextEditingController();
  final _areaController = TextEditingController();
  final _addictionsController = TextEditingController();
  final _complaintCustomController = TextEditingController();
  final _commentsController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _altPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pinController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _policyNumberController = TextEditingController();

  DateTime? _dob;
  String? _gender;
  String? _healthScheme;
  String? _chiefComplaint;
  String? _emergencyRelationship;
  String? _bloodGroup;
  bool _isHighPriority = false;
  bool _isLoading = false;
  bool _consentDataStorage = false;
  bool _consentIdVerified = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit && widget.patientId != null) {
      _loadExistingPatient();
      _isInit = true;
    }
  }

  Future<void> _loadExistingPatient() async {
    setState(() => _isLoading = true);
    try {
      final patient =
          await ref.read(patientDetailProvider(widget.patientId!).future);
      if (patient != null && mounted) {
        setState(() {
          _nameController.text = patient['full_name'] ?? '';
          _phoneController.text = patient['phone'] ?? '';
          _emailController.text = patient['email'] ?? '';
          _emergencyPhoneController.text =
              patient['emergency_contact_number'] ?? '';
          _occupationController.text = patient['occupation'] ?? '';
          _schemeOtherController.text = patient['health_scheme_other'] ?? '';
          _symptomsController.text = patient['symptoms'] ?? '';
          _areaController.text = patient['area_affected'] ?? '';
          _addictionsController.text = patient['addictions'] ?? '';
          _complaintCustomController.text =
              patient['chief_complaint_custom'] ?? '';
          _commentsController.text = patient['staff_comments'] ?? '';
          _nationalIdController.text = patient['national_id'] ?? '';
          _altPhoneController.text = patient['alternate_phone'] ?? '';
          _addressController.text = patient['address'] ?? '';
          _cityController.text = patient['city'] ?? '';
          _stateController.text = patient['state'] ?? '';
          _pinController.text = patient['pin_code'] ?? '';
          _emergencyNameController.text =
              patient['emergency_contact_name'] ?? '';
          _allergiesController.text = patient['allergies'] ?? '';
          _conditionsController.text = patient['existing_conditions'] ?? '';
          _medicationsController.text = patient['current_medications'] ?? '';
          _policyNumberController.text = patient['policy_number'] ?? '';

          _gender = patient['gender'];
          _healthScheme = patient['health_scheme'];
          _chiefComplaint = patient['chief_complaint'];
          _isHighPriority = patient['is_high_priority'] ?? false;
          _emergencyRelationship = patient['emergency_relationship'];
          _bloodGroup = patient['blood_group'];
          if (patient['date_of_birth'] != null) {
            _dob = DateTime.parse(patient['date_of_birth']);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, AppError.getMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _emergencyPhoneController.dispose();
    _occupationController.dispose();
    _schemeOtherController.dispose();
    _symptomsController.dispose();
    _areaController.dispose();
    _addictionsController.dispose();
    _complaintCustomController.dispose();
    _commentsController.dispose();
    _nationalIdController.dispose();
    _altPhoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pinController.dispose();
    _emergencyNameController.dispose();
    _allergiesController.dispose();
    _conditionsController.dispose();
    _medicationsController.dispose();
    _policyNumberController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_consentDataStorage || !_consentIdVerified) {
      AppSnackbar.showError(
          context, 'Please confirm both consent checkboxes before saving.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final patientData = {
        'full_name': _nameController.text,
        'date_of_birth': _dob?.toIso8601String().split('T')[0],
        'gender': _gender,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'emergency_contact_number': _emergencyPhoneController.text,
        'occupation': _occupationController.text,
        'health_scheme': _healthScheme,
        'health_scheme_other': _schemeOtherController.text,
        'symptoms': _symptomsController.text,
        'area_affected': _areaController.text,
        'addictions': _addictionsController.text,
        'chief_complaint': _chiefComplaint,
        'chief_complaint_custom': _complaintCustomController.text,
        'is_high_priority': _isHighPriority,
        'staff_comments': _commentsController.text,
        'blood_group': _bloodGroup,
        'national_id': _nationalIdController.text,
        'alternate_phone': _altPhoneController.text,
        'address': _addressController.text,
        'city': _cityController.text,
        'state': _stateController.text,
        'pin_code': _pinController.text,
        'emergency_contact_name': _emergencyNameController.text,
        'emergency_relationship': _emergencyRelationship,
        'allergies': _allergiesController.text,
        'existing_conditions': _conditionsController.text,
        'current_medications': _medicationsController.text,
        'policy_number': _policyNumberController.text,
      };

      if (widget.patientId != null) {
        await ref
            .read(patientProvider)
            .updatePatient(widget.patientId!, patientData);
      } else {
        await ref.read(patientProvider).registerPatient(patientData);
      }

      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'Saved successfully');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, AppError.getMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.patientId != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Patient' : 'Patient Registration',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading && isEdit
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildSectionCard('Personal Details', Icons.person, [
                      _buildTextField(_nameController, 'Full Name',
                          required: true),
                      _buildDatePicker(),
                      _buildDropdown('Gender', ['Male', 'Female', 'Other'],
                          (val) => setState(() => _gender = val), _gender),
                      _buildTextField(_phoneController, 'Phone Number',
                          keyboard: TextInputType.phone),
                      _buildTextField(_emailController, 'Email ID',
                          keyboard: TextInputType.emailAddress),
                      _buildTextField(_occupationController, 'Occupation'),
                      _buildBloodGroupDropdown(),
                      _buildTextField(
                          _nationalIdController, 'National ID / Aadhaar',
                          required: true),
                    ]),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                        'Health & Insurance', Icons.health_and_safety, [
                      _buildDropdown(
                          'Health Scheme',
                          ['insurance', 'cash', 'sastho_sathi', 'other'],
                          (val) => setState(() => _healthScheme = val),
                          _healthScheme),
                      if (_healthScheme == 'other')
                        _buildTextField(
                            _schemeOtherController, 'Please specify scheme'),
                      if (_healthScheme == 'insurance')
                        _buildTextField(
                            _policyNumberController, 'Policy Number'),
                    ]),
                    const SizedBox(height: 16),
                    _buildSectionCard('Address', Icons.location_on, [
                      _buildTextField(_addressController, 'Residential Address',
                          required: true),
                      _buildTextField(_cityController, 'City', required: true),
                      _buildTextField(_stateController, 'State',
                          required: true),
                      _buildTextField(_pinController, 'PIN Code',
                          keyboard: TextInputType.number, required: true),
                    ]),
                    const SizedBox(height: 16),
                    _buildSectionCard('Emergency Contact', Icons.emergency, [
                      _buildTextField(_emergencyNameController, 'Contact Name',
                          required: true),
                      _buildRelationshipDropdown(),
                      _buildTextField(
                          _emergencyPhoneController, 'Emergency Contact',
                          keyboard: TextInputType.phone),
                      _buildTextField(_altPhoneController, 'Alternate Phone',
                          keyboard: TextInputType.phone),
                    ]),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                        'Medical Information', Icons.medical_services, [
                      _buildDropdown(
                          'Chief Complaint',
                          ['Fever', 'Pain', 'Injury', 'Post-Op', 'Other'],
                          (val) => setState(() => _chiefComplaint = val),
                          _chiefComplaint),
                      if (_chiefComplaint == 'Other')
                        _buildTextField(
                            _complaintCustomController, 'Custom Complaint'),
                      _buildTextField(_symptomsController, 'Symptoms',
                          multiLine: true),
                      _buildTextField(_areaController, 'Area Affected'),
                      _buildTextField(_addictionsController, 'Addictions',
                          hint: 'e.g. smoking, alcohol'),
                      const SizedBox(height: 8),
                      _buildTextField(_allergiesController, 'Known Allergies',
                          multiLine: true),
                      _buildTextField(
                          _conditionsController, 'Existing Conditions',
                          multiLine: true),
                      _buildTextField(
                          _medicationsController, 'Current Medications',
                          multiLine: true),
                    ]),
                    const SizedBox(height: 16),
                    _buildSectionCard('Flags & Handoff', Icons.flag, [
                      _buildPriorityToggle(),
                      _buildTextField(_commentsController, 'Staff Comments',
                          multiLine: true),
                    ]),
                    if (!isEdit) ...[
                      const SizedBox(height: 16),
                      _buildSectionCard('Consent', Icons.verified_user, [
                        CheckboxListTile(
                          title: const Text(
                              'Patient has given consent for data storage'),
                          value: _consentDataStorage,
                          onChanged: (val) => setState(
                              () => _consentDataStorage = val ?? false),
                          activeColor: AppTheme.primaryTeal,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          title: const Text(
                              'Patient information verified against a valid ID'),
                          value: _consentIdVerified,
                          onChanged: (val) =>
                              setState(() => _consentIdVerified = val ?? false),
                          activeColor: AppTheme.primaryTeal,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ]),
                    ],
                    if (isEdit) ...[
                      const SizedBox(height: 16),
                      DocumentUploadWidget(patientId: widget.patientId!),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: NeuButton(
                        onPressed: _isLoading ? null : _submitForm,
                        isLoading: _isLoading,
                        child: Text(
                            isEdit ? 'SAVE CHANGES' : 'REGISTER PATIENT',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return NeuCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: AppTheme.primaryTeal, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF718096),
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600)),
            ]),
            const Divider(height: 24),
            ...children.expand((w) => [w, const SizedBox(height: 12)]).toList()
              ..removeLast(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool required = false,
      TextInputType? keyboard,
      bool multiLine = false,
      String? hint}) {
    return NeuTextField(
      controller: controller,
      label: label,
      hint: hint,
      keyboardType: keyboard,
      maxLines: multiLine ? 3 : 1,
      validator: required
          ? (val) => val == null || val.isEmpty ? 'Required field' : null
          : null,
    );
  }

  Widget _buildDropdown(String label, List<String> items,
      Function(String?) onChanged, String? value) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((i) => DropdownMenuItem(value: i, child: Text(i.toUpperCase())))
          .toList(),
      onChanged: onChanged,
      validator: (val) => val == null ? 'Please select' : null,
    );
  }

  Widget _buildBloodGroupDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _bloodGroup,
      decoration: const InputDecoration(labelText: 'Blood Group'),
      items: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-']
          .map((i) => DropdownMenuItem(value: i, child: Text(i)))
          .toList(),
      onChanged: (val) => setState(() => _bloodGroup = val),
    );
  }

  Widget _buildRelationshipDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _emergencyRelationship,
      decoration: const InputDecoration(labelText: 'Relationship'),
      items: ['Spouse', 'Parent', 'Child', 'Sibling', 'Guardian', 'Other']
          .map((i) => DropdownMenuItem(value: i, child: Text(i)))
          .toList(),
      onChanged: (val) => setState(() => _emergencyRelationship = val),
      validator: (val) => val == null ? 'Please select' : null,
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
            context: context,
            initialDate: _dob ?? DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime.now());
        if (date != null) setState(() => _dob = date);
      },
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Date of Birth'),
        child: Text(_dob == null
            ? 'Select Date'
            : DateFormat('yyyy-MM-dd').format(_dob!)),
      ),
    );
  }

  Widget _buildPriorityToggle() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _isHighPriority
            ? Colors.red.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _isHighPriority ? Colors.red : Colors.grey.shade300),
      ),
      child: SwitchListTile(
        title: const Text('High Priority Case',
            style: TextStyle(fontWeight: FontWeight.bold)),
        value: _isHighPriority,
        activeThumbColor: Colors.red,
        onChanged: (val) => setState(() => _isHighPriority = val),
      ),
    );
  }
}
