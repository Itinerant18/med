// lib/features/patients/patient_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/patients/patient_provider.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/app_snackbar.dart';

class PatientFormScreen extends ConsumerStatefulWidget {
  final String? patientId;
  const PatientFormScreen({super.key, this.patientId});

  @override
  ConsumerState<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends ConsumerState<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  // Track which patientId we last loaded so we re-fetch if the widget is
  // reused with a different id (e.g. cached routes).
  String? _loadedPatientId;
  bool _isLoading = false;

  // Personal Details
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _occupationController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _altPhoneController = TextEditingController();
  DateTime? _dob;
  String? _gender;
  String? _bloodGroup;

  // Address
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pinController = TextEditingController();

  // Emergency Contact
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  String? _emergencyRelationship;

  // Health & Insurance
  String? _healthScheme;
  final _schemeOtherController = TextEditingController();
  final _policyNumberController = TextEditingController();

  // Medical Info
  final _symptomsController = TextEditingController();
  final _areaController = TextEditingController();
  final _addictionsController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _medicationsController = TextEditingController();
  String? _chiefComplaint;
  final _complaintCustomController = TextEditingController();

  // Flags
  bool _isHighPriority = false;
  final _commentsController = TextEditingController();

  // Consent (only for new patients)
  bool _consentDataStorage = false;
  bool _consentIdVerified = false;

  bool get _isEdit => widget.patientId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isEdit && _loadedPatientId != widget.patientId) {
      _loadedPatientId = widget.patientId;
      _loadExistingPatient();
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
            _dob = DateTime.tryParse(patient['date_of_birth']);
          }
        });
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, AppError.getMessage(e));
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
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      AppSnackbar.showWarning(context, 'Please fix the errors in the form.');
      return;
    }

    if (!_isEdit && (!_consentDataStorage || !_consentIdVerified)) {
      AppSnackbar.showError(
          context, 'Please confirm both consent checkboxes before saving.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final patientData = {
        'full_name': _nameController.text.trim(),
        'date_of_birth': _dob?.toIso8601String().split('T')[0],
        'gender': _gender,
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'emergency_contact_number': _emergencyPhoneController.text.trim(),
        'occupation': _occupationController.text.trim(),
        'health_scheme': _healthScheme,
        'health_scheme_other': _schemeOtherController.text.trim(),
        'symptoms': _symptomsController.text.trim(),
        'area_affected': _areaController.text.trim(),
        'addictions': _addictionsController.text.trim(),
        'chief_complaint': _chiefComplaint,
        'chief_complaint_custom': _complaintCustomController.text.trim(),
        'is_high_priority': _isHighPriority,
        'staff_comments': _commentsController.text.trim(),
        'blood_group': _bloodGroup,
        'national_id': _nationalIdController.text.trim(),
        'alternate_phone': _altPhoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pin_code': _pinController.text.trim(),
        'emergency_contact_name': _emergencyNameController.text.trim(),
        'emergency_relationship': _emergencyRelationship,
        'allergies': _allergiesController.text.trim(),
        'existing_conditions': _conditionsController.text.trim(),
        'current_medications': _medicationsController.text.trim(),
        'policy_number': _policyNumberController.text.trim(),
      };

      if (_isEdit) {
        await ref
            .read(patientProvider)
            .updatePatient(widget.patientId!, patientData);
      } else {
        await ref.read(patientProvider).registerPatient(patientData);
      }

      if (!mounted) return;
      AppSnackbar.showSuccess(
          context,
          _isEdit
              ? 'Patient updated successfully'
              : 'Patient registered successfully');
      context.pop(true);
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, AppError.getMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit Patient' : 'Register Patient',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading && _isEdit
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildSection(
                        'Personal Details', Icons.person_outline_rounded, [
                      _textField(_nameController, 'Full Name *',
                          required: true, capitalize: TextCapitalization.words),
                      _datePicker(),
                      _dropdown('Gender', ['Male', 'Female', 'Other'],
                          (v) => setState(() => _gender = v), _gender,
                          required: true),
                      _textField(_phoneController, 'Phone Number',
                          keyboard: TextInputType.phone),
                      _textField(_emailController, 'Email Address',
                          keyboard: TextInputType.emailAddress, validator: (v) {
                        if (v != null &&
                            v.isNotEmpty &&
                            !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v)) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      }),
                      _textField(_occupationController, 'Occupation',
                          capitalize: TextCapitalization.words),
                      _bloodGroupDropdown(),
                      _textField(
                          _nationalIdController, 'National ID / Aadhaar *',
                          required: true),
                    ]),
                    const SizedBox(height: 16),

                    _buildSection('Address', Icons.location_on_outlined, [
                      _textField(_addressController, 'Residential Address *',
                          required: true, multiLine: true),
                      _textField(_cityController, 'City *',
                          required: true, capitalize: TextCapitalization.words),
                      _textField(_stateController, 'State *',
                          required: true, capitalize: TextCapitalization.words),
                      _textField(_pinController, 'PIN Code *',
                          keyboard: TextInputType.number,
                          required: true, validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length != 6 || int.tryParse(v) == null) {
                          return 'Enter a valid 6-digit PIN code';
                        }
                        return null;
                      }),
                    ]),
                    const SizedBox(height: 16),

                    _buildSection(
                        'Emergency Contact', Icons.emergency_outlined, [
                      _textField(_emergencyNameController, 'Contact Name *',
                          required: true, capitalize: TextCapitalization.words),
                      _dropdown(
                          'Relationship *',
                          [
                            'Spouse',
                            'Parent',
                            'Child',
                            'Sibling',
                            'Guardian',
                            'Other'
                          ],
                          (v) => setState(() => _emergencyRelationship = v),
                          _emergencyRelationship,
                          required: true),
                      _textField(_emergencyPhoneController, 'Emergency Phone *',
                          keyboard: TextInputType.phone, required: true),
                      _textField(_altPhoneController, 'Alternate Phone',
                          keyboard: TextInputType.phone),
                    ]),
                    const SizedBox(height: 16),

                    _buildSection('Health & Insurance',
                        Icons.health_and_safety_outlined, [
                      _dropdown(
                          'Health Scheme',
                          ['insurance', 'cash', 'sastho_sathi', 'other'],
                          (v) => setState(() => _healthScheme = v),
                          _healthScheme),
                      if (_healthScheme == 'other')
                        _textField(
                            _schemeOtherController, 'Please specify scheme *',
                            required: true),
                      if (_healthScheme == 'insurance')
                        _textField(_policyNumberController, 'Policy Number'),
                    ]),
                    const SizedBox(height: 16),

                    _buildSection('Medical Information',
                        Icons.medical_information_outlined, [
                      _dropdown(
                          'Chief Complaint',
                          [
                            'Fever',
                            'Pain',
                            'Injury',
                            'Respiratory',
                            'Post-Op',
                            'Follow-up',
                            'Other'
                          ],
                          (v) => setState(() {
                                _chiefComplaint = v;
                              }),
                          _chiefComplaint),
                      if (_chiefComplaint == 'Other')
                        _textField(
                            _complaintCustomController, 'Describe Complaint',
                            multiLine: true),
                      _textField(_symptomsController, 'Symptoms',
                          multiLine: true,
                          hint: 'e.g. headache, fever, nausea'),
                      _textField(_areaController, 'Area Affected',
                          hint: 'e.g. chest, abdomen, head'),
                      _textField(_addictionsController, 'Addictions',
                          hint: 'e.g. smoking, alcohol, none'),
                      _textField(_allergiesController, 'Known Allergies',
                          multiLine: true,
                          hint: 'Drug, food, or other allergies'),
                      _textField(_conditionsController, 'Existing Conditions',
                          multiLine: true,
                          hint: 'Diabetes, hypertension, etc.'),
                      _textField(_medicationsController, 'Current Medications',
                          multiLine: true, hint: 'Name, dose, frequency'),
                    ]),
                    const SizedBox(height: 16),

                    _buildSection('Flags & Notes', Icons.flag_outlined, [
                      _priorityToggle(),
                      _textField(_commentsController, 'Staff Comments',
                          multiLine: true, hint: 'Any additional notes...'),
                    ]),

                    // Consent section — only for new patients
                    if (!_isEdit) ...[
                      const SizedBox(height: 16),
                      NeuCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionTitle(
                                title: 'Patient Consent',
                                icon: Icons.verified_user_outlined),
                            _consentCheckbox(
                              value: _consentDataStorage,
                              label:
                                  'Patient has given consent for data storage and processing',
                              onChanged: (v) => setState(
                                  () => _consentDataStorage = v ?? false),
                            ),
                            const SizedBox(height: 8),
                            _consentCheckbox(
                              value: _consentIdVerified,
                              label:
                                  'Patient identity verified against a valid government ID',
                              onChanged: (v) => setState(
                                  () => _consentIdVerified = v ?? false),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: NeuButton(
                        onPressed: _isLoading ? null : _submitForm,
                        isLoading: _isLoading,
                        child: Text(
                          _isEdit ? 'SAVE CHANGES' : 'REGISTER PATIENT',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return NeuCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(title: title, icon: icon),
            ...children.expand((w) => [w, const SizedBox(height: 12)]).toList()
              ..removeLast(),
          ],
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboard,
    bool multiLine = false,
    String? hint,
    TextCapitalization capitalize = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return NeuTextField(
      controller: controller,
      label: label,
      hint: hint,
      keyboardType: keyboard,
      maxLines: multiLine ? 3 : 1,
      textCapitalization: capitalize,
      validator: validator ??
          (required
              ? (val) => val == null || val.trim().isEmpty
                  ? 'This field is required'
                  : null
              : null),
    );
  }

  Widget _dropdown(
    String label,
    List<String> items,
    Function(String?) onChanged,
    String? value, {
    bool required = false,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      hint: Text('Select ${label.replaceAll(' *', '')}'),
      items: items
          .map((i) => DropdownMenuItem(
              value: i, child: Text(i.replaceAll('_', ' ').toUpperCase())))
          .toList(),
      onChanged: onChanged,
      validator:
          required ? (v) => v == null ? 'Please select an option' : null : null,
    );
  }

  Widget _bloodGroupDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _bloodGroup,
      decoration: const InputDecoration(labelText: 'Blood Group'),
      hint: const Text('Select blood group'),
      items: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-']
          .map((i) => DropdownMenuItem(value: i, child: Text(i)))
          .toList(),
      onChanged: (val) => setState(() => _bloodGroup = val),
    );
  }

  Widget _datePicker() {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate:
              _dob ?? DateTime.now().subtract(const Duration(days: 365 * 30)),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme:
                  const ColorScheme.light(primary: AppTheme.primaryTeal),
            ),
            child: child!,
          ),
        );
        if (date != null) setState(() => _dob = date);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Colors.white, offset: Offset(-3, -3), blurRadius: 8),
            BoxShadow(
                color: Color(0xFFA3B1C6), offset: Offset(3, 3), blurRadius: 8),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                color: AppTheme.primaryTeal, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Date of Birth',
                      style:
                          TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    _dob == null
                        ? 'Tap to select'
                        : DateFormat('MMMM d, yyyy').format(_dob!),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _dob == null
                          ? AppTheme.textMuted
                          : AppTheme.textColor,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _priorityToggle() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isHighPriority
            ? Colors.red.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              _isHighPriority ? Colors.red.shade300 : const Color(0xFFD1D9E6),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.priority_high_rounded,
            color: _isHighPriority ? Colors.red : AppTheme.textMuted,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'High Priority Case',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _isHighPriority ? Colors.red : AppTheme.textColor,
                  ),
                ),
                Text(
                  _isHighPriority
                      ? 'This patient needs immediate attention'
                      : 'Mark if patient requires urgent care',
                  style:
                      const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          Switch(
            value: _isHighPriority,
            activeThumbColor: Colors.red,
            activeTrackColor: Colors.red.withValues(alpha: 0.3),
            onChanged: (val) => setState(() => _isHighPriority = val),
          ),
        ],
      ),
    );
  }

  Widget _consentCheckbox({
    required bool value,
    required String label,
    required ValueChanged<bool?> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.primaryTeal,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: AppTheme.textColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
