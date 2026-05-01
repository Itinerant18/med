import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/neu_widgets.dart';
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

  final _formKey = GlobalKey<FormState>();
  String? _loadedPatientId;
  bool _isLoading = false;

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _investigationPlaceController = TextEditingController();
  final _referredByController = TextEditingController();
  final Map<String, String> _investigationStatus = {
    'Blood Test': 'na',
    'CT Scan': 'na',
    'MRI': 'na',
    'HRCT Thorax': 'na',
    'Biopsy Report': 'na',
  };

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
          _addressController.text = patient['address']?.toString() ?? '';
          _investigationPlaceController.text =
              patient['investigation_place']?.toString() ?? '';
          _referredByController.text = patient['referred_by']?.toString() ?? '';

          for (final name in _investigations) {
            _investigationStatus[name] = 'na';
          }

          final savedStatus = patient['investigation_status'];
          if (savedStatus is Map) {
            savedStatus.forEach((k, v) {
              final key = k.toString();
              if (_investigationStatus.containsKey(key)) {
                final value =
                    v.toString().toLowerCase() == 'done' ? 'done' : 'na';
                _investigationStatus[key] = value;
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
    _addressController.dispose();
    _investigationPlaceController.dispose();
    _referredByController.dispose();
    super.dispose();
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
        'address': _addressController.text.trim(),
        'investigation_place': _investigationPlaceController.text.trim(),
        'investigation_status': Map<String, dynamic>.from(_investigationStatus),
        'referred_by': _referredByController.text.trim(),
        'last_updated_by': doctorName,
        'last_updated_at': nowIso,
        'created_by_id': createdById,
        'service_status': serviceStatus,
        'created_at': createdAt,
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    NeuCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          NeuTextField(
                            controller: _nameController,
                            label: 'Full name',
                            textCapitalization: TextCapitalization.words,
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Full name required'
                                    : null,
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
                            controller: _investigationPlaceController,
                            label: 'Investigation place',
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 12),
                          _investigationStatusSection(),
                          const SizedBox(height: 12),
                          NeuTextField(
                            controller: _referredByController,
                            label: 'Referred by',
                            textCapitalization: TextCapitalization.words,
                          ),
                        ],
                      ),
                    ),
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
