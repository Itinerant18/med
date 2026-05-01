import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/parse_utils.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/features/patients/patient_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PatientFormScreen extends ConsumerStatefulWidget {
  final String? patientId;

  const PatientFormScreen({super.key, this.patientId});

  @override
  ConsumerState<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends ConsumerState<PatientFormScreen> {
  static const List<String> _investigations = [
    'Blood Test',
    'CT Scan',
    'MRI',
    'HRCT Thorax',
    'Biopsy Report',
  ];

  static const List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
  ];

  static const List<String> _bloodGroupOptions = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  static const List<String> _healthSchemeOptions = [
    'cash',
    'insurance',
    'sastho_sathi',
    'other',
  ];

  final _formKey = GlobalKey<FormState>();
  String? _loadedPatientId;
  bool _isLoading = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emailController = TextEditingController();
  final _symptomsController = TextEditingController();
  final _areaAffectedController = TextEditingController();
  final _existingConditionsController = TextEditingController();
  final _currentMedicationsController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _addictionsController = TextEditingController();
  final _addressController = TextEditingController();
  final _referredByController = TextEditingController();
  final _investigationPlaceController = TextEditingController();
  final _staffCommentsController = TextEditingController();

  final Map<String, String> _investigationStatus = {
    'Blood Test': 'na',
    'CT Scan': 'na',
    'MRI': 'na',
    'HRCT Thorax': 'na',
    'Biopsy Report': 'na',
  };

  DateTime? _dob;
  String? _gender;
  String? _bloodGroup;
  String? _healthScheme;
  bool _isHighPriority = false;

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
          _nameController.text = patient['full_name']?.toString() ?? '';
          _phoneController.text = patient['phone']?.toString() ?? '';
          _emergencyContactController.text =
              patient['emergency_contact_number']?.toString() ?? '';
          _emailController.text = patient['email']?.toString() ?? '';
          _symptomsController.text = patient['symptoms']?.toString() ?? '';
          _areaAffectedController.text =
              patient['area_affected']?.toString() ?? '';
          _existingConditionsController.text =
              patient['existing_conditions']?.toString() ?? '';
          _currentMedicationsController.text =
              patient['current_medications']?.toString() ?? '';
          _allergiesController.text = patient['allergies']?.toString() ?? '';
          _addictionsController.text = patient['addictions']?.toString() ?? '';
          _addressController.text = patient['address']?.toString() ?? '';
          _referredByController.text = patient['referred_by']?.toString() ?? '';
          _investigationPlaceController.text =
              patient['investigation_place']?.toString() ?? '';
          _staffCommentsController.text =
              patient['staff_comments']?.toString() ?? '';

          _dob = parseDbDate(patient['date_of_birth']);
          _gender = patient['gender']?.toString();
          _bloodGroup = patient['blood_group']?.toString();

          final scheme = patient['health_scheme']?.toString().toLowerCase();
          _healthScheme = _healthSchemeOptions.contains(scheme) ? scheme : null;

          _isHighPriority = patient['is_high_priority'] == true;

          for (final name in _investigations) {
            _investigationStatus[name] = 'na';
          }

          final savedStatus = patient['investigation_status'];
          if (savedStatus is Map) {
            savedStatus.forEach((k, v) {
              final key = k.toString();
              if (_investigationStatus.containsKey(key)) {
                _investigationStatus[key] =
                    v.toString().toLowerCase() == 'done' ? 'done' : 'na';
              }
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, AppError.getMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emergencyContactController.dispose();
    _emailController.dispose();
    _symptomsController.dispose();
    _areaAffectedController.dispose();
    _existingConditionsController.dispose();
    _currentMedicationsController.dispose();
    _allergiesController.dispose();
    _addictionsController.dispose();
    _addressController.dispose();
    _referredByController.dispose();
    _investigationPlaceController.dispose();
    _staffCommentsController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _dob = picked);
    }
  }

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      AppSnackbar.showWarning(context, 'Please fix form errors.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authNotifierProvider).valueOrNull;
      final userId = authState?.session.user.id ??
          Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Not authenticated. Please sign in again.');
      }

      final doctorName = authState?.doctorName ?? 'Staff';
      final nowIso = DateTime.now().toIso8601String();

      String? createdById = userId;
      String serviceStatus = 'pending';
      String createdAt = nowIso;

      if (_isEdit) {
        final existing =
            await ref.read(patientDetailProvider(widget.patientId!).future);
        if (existing != null) {
          createdById = existing['created_by_id']?.toString() ?? createdById;
          serviceStatus =
              existing['service_status']?.toString() ?? serviceStatus;
          createdAt = existing['created_at']?.toString() ?? createdAt;
        }
      }

      final patientData = <String, dynamic>{
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'emergency_contact_number': _emergencyContactController.text.trim(),
        'email': _emailController.text.trim(),
        'date_of_birth': _dob == null
            ? null
            : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
        'gender': _gender,
        'blood_group': _bloodGroup,
        'symptoms': _symptomsController.text.trim(),
        'area_affected': _areaAffectedController.text.trim(),
        'existing_conditions': _existingConditionsController.text.trim(),
        'current_medications': _currentMedicationsController.text.trim(),
        'allergies': _allergiesController.text.trim(),
        'addictions': _addictionsController.text.trim(),
        'health_scheme': _healthScheme?.toLowerCase(),
        'address': _addressController.text.trim(),
        'referred_by': _referredByController.text.trim(),
        'investigation_place': _investigationPlaceController.text.trim(),
        'investigation_status': Map<String, dynamic>.from(_investigationStatus),
        'is_high_priority': _isHighPriority,
        'staff_comments': _staffCommentsController.text.trim(),
        'last_updated_by': doctorName,
        'last_updated_at': nowIso,
        'created_by_id': createdById,
        'service_status': serviceStatus,
        'created_at': createdAt,
      };

      patientData.removeWhere((key, value) {
        if (value == null) return true;
        if (value is String && value.trim().isEmpty) return true;
        return false;
      });

      if (_isEdit) {
        await ref
            .read(patientProvider.notifier)
            .updatePatient(widget.patientId!, patientData);
      } else {
        await ref.read(patientProvider.notifier).registerPatient(patientData);
      }

      if (!mounted) return;
      AppSnackbar.showSuccess(
        context,
        _isEdit
            ? 'Patient updated successfully'
            : 'Patient registered successfully',
      );
      context.pop(true);
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, AppError.getMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
              child: CircularProgressIndicator(color: AppTheme.primaryTeal),
            )
          : Stack(
              children: [
                Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 132),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle(
                          title: 'Basic Information',
                          icon: AppIcons.person_rounded,
                        ),
                        NeuCard(
                          child: Column(
                            children: [
                              NeuTextField(
                                controller: _nameController,
                                label: 'Full Name',
                                textCapitalization: TextCapitalization.words,
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Full name required'
                                        : null,
                              ),
                              const SizedBox(height: 12),
                              NeuTextField(
                                controller: _phoneController,
                                label: 'Phone',
                                keyboardType: TextInputType.phone,
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Phone required'
                                        : null,
                              ),
                              const SizedBox(height: 12),
                              NeuTextField(
                                controller: _emergencyContactController,
                                label: 'Emergency Contact Number',
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 12),
                              NeuTextField(
                                controller: _emailController,
                                label: 'Email',
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: _pickDob,
                                child: NeuCard(
                                  color: AppTheme.bgColor,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        AppIcons.calendar_today_rounded,
                                        size: 18,
                                        color: AppTheme.primaryTeal,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Date of Birth',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.textMuted,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _dob == null
                                                  ? 'Select date of birth'
                                                  : DateFormat('dd MMM yyyy')
                                                      .format(_dob!),
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: _dob == null
                                                    ? AppTheme.textMuted
                                                    : AppTheme.textColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        AppIcons.chevron_right_rounded,
                                        size: 16,
                                        color: AppTheme.textMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildDropdownField(
                                label: 'Gender',
                                value: _gender,
                                items: _genderOptions,
                                onChanged: (value) =>
                                    setState(() => _gender = value),
                              ),
                              const SizedBox(height: 12),
                              _buildDropdownField(
                                label: 'Blood Group',
                                value: _bloodGroup,
                                items: _bloodGroupOptions,
                                onChanged: (value) =>
                                    setState(() => _bloodGroup = value),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const SectionTitle(
                          title: 'Clinical Information',
                          icon: AppIcons.medical_information_outlined,
                        ),
                        NeuCard(
                          child: Column(
                            children: [
                              NeuTextField(
                                controller: _symptomsController,
                                label: 'Symptoms',
                                maxLines: 3,
                              ),
                              const SizedBox(height: 12),
                              NeuTextField(
                                controller: _areaAffectedController,
                                label: 'Area Affected',
                              ),
                              const SizedBox(height: 12),
                              NeuTextField(
                                controller: _existingConditionsController,
                                label: 'Existing Conditions',
                                maxLines: 3,
                              ),
                              const SizedBox(height: 12),
                              NeuTextField(
                                controller: _currentMedicationsController,
                                label: 'Current Medications',
                                maxLines: 3,
                              ),
                              const SizedBox(height: 12),
                              NeuTextField(
                                controller: _allergiesController,
                                label: 'Allergies',
                              ),
                              const SizedBox(height: 12),
                              NeuTextField(
                                controller: _addictionsController,
                                label: 'Addictions',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const SectionTitle(
                          title: 'Administrative',
                          icon: AppIcons.assignment_outlined,
                        ),
                        NeuCard(
                          child: Column(
                            children: [
                              _buildDropdownField(
                                label: 'Health Scheme',
                                value: _healthScheme,
                                items: _healthSchemeOptions,
                                onChanged: (value) =>
                                    setState(() => _healthScheme = value),
                                labelBuilder: (value) => switch (value) {
                                  'sastho_sathi' => 'Sastho Sathi',
                                  _ => _titleCase(value),
                                },
                              ),
                              const SizedBox(height: 12),
                              NeuTextField(
                                controller: _addressController,
                                label: 'Address',
                                maxLines: 3,
                                textCapitalization: TextCapitalization.words,
                              ),
                              const SizedBox(height: 12),
                              NeuTextField(
                                controller: _referredByController,
                                label: 'Referred By',
                                textCapitalization: TextCapitalization.words,
                              ),
                              const SizedBox(height: 12),
                              NeuTextField(
                                controller: _investigationPlaceController,
                                label: 'Investigation Place',
                                textCapitalization: TextCapitalization.words,
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgColor,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'High Priority Patient',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textColor,
                                        ),
                                      ),
                                    ),
                                    Switch(
                                      value: _isHighPriority,
                                      activeThumbColor: AppTheme.errorColor,
                                      activeTrackColor: AppTheme.errorColor
                                          .withValues(alpha: 0.35),
                                      onChanged: (value) => setState(
                                        () => _isHighPriority = value,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              NeuTextField(
                                controller: _staffCommentsController,
                                label: 'Staff Comments',
                                maxLines: 3,
                              ),
                              const SizedBox(height: 12),
                              _investigationStatusSection(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
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
                            color: AppTheme.primaryForeground,
                            letterSpacing: 0.8,
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

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String Function(String value)? labelBuilder,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(labelBuilder?.call(item) ?? item),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value
        .split('_')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Widget _investigationStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          title: 'Investigations done',
          icon: AppIcons.biotech_rounded,
        ),
        ..._investigations.map(
          (name) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ChoiceChip(
                  label: const Text(' Done'),
                  selected: _investigationStatus[name] == 'done',
                  onSelected: (_) =>
                      setState(() => _investigationStatus[name] = 'done'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('N/A'),
                  selected: _investigationStatus[name] == 'na',
                  onSelected: (_) =>
                      setState(() => _investigationStatus[name] = 'na'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
