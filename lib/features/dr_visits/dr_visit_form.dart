import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/dr_visits/dr_visit_provider.dart';
import 'package:mediflow/features/dr_visits/agents_provider.dart';
import 'package:mediflow/features/patients/patient_list_provider.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/core/error_handler.dart';

class DrVisitForm extends ConsumerStatefulWidget {
  const DrVisitForm({super.key});

  @override
  ConsumerState<DrVisitForm> createState() => _DrVisitFormState();
}

class _DrVisitFormState extends ConsumerState<DrVisitForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  String? _selectedPatientId;
  String? _selectedPatientName;
  String? _selectedAgentId;

  final _visitNotesController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _followupNotesController = TextEditingController();
  DateTime? _followupDate;

  @override
  void dispose() {
    _visitNotesController.dispose();
    _diagnosisController.dispose();
    _followupNotesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedPatientId == null) {
      AppSnackbar.showError(context, 'Please select a patient');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(drVisitsProvider.notifier).createVisit(
            patientId: _selectedPatientId!,
            assignedAgentId: _selectedAgentId,
            visitNotes: _visitNotesController.text.trim(),
            diagnosis: _diagnosisController.text.trim(),
            followupDate: _followupDate,
            followupNotes: _followupNotesController.text.trim(),
          );
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Visit recorded successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, AppError.getMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPatientPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => const _PatientPickerSheet(),
    ).then((result) {
      if (result != null && result is Map<String, String>) {
        setState(() {
          _selectedPatientId = result['id'];
          _selectedPatientName = result['name'];
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final assistantsAsync = ref.watch(agentsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text('New Dr Visit',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Selection
              const SectionTitle(
                  title: 'Patient', icon: Icons.person_search_rounded),
              GestureDetector(
                onTap: _showPatientPicker,
                child: NeuCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.person_rounded,
                          color: _selectedPatientId == null
                              ? AppTheme.textMuted
                              : AppTheme.primaryTeal),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedPatientName ?? 'Select Patient',
                          style: TextStyle(
                            fontSize: 16,
                            color: _selectedPatientId == null
                                ? AppTheme.textMuted
                                : AppTheme.textColor,
                            fontWeight: _selectedPatientId == null
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down_rounded,
                          color: AppTheme.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Agent Assignment
              const SectionTitle(
                  title: 'Assign Assistant',
                  icon: Icons.assignment_ind_outlined),
              assistantsAsync.when(
                data: (assistants) => NeuCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: DropdownButtonFormField<String>(
                    value: _selectedAgentId,
                    decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none),
                    hint: const Text('Select Assistant (Optional)'),
                    items: assistants
                        .map((a) => DropdownMenuItem(
                            value: a.id, child: Text(a.fullName)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedAgentId = val),
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Error loading assistants: $err'),
              ),
              const SizedBox(height: 24),

              // Visit Details
              const SectionTitle(
                  title: 'Visit Details',
                  icon: Icons.medical_information_outlined),
              NeuTextField(
                controller: _visitNotesController,
                label: 'Visit Notes',
                hint: 'Reason for visit, symptoms, observations...',
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              NeuTextField(
                controller: _diagnosisController,
                label: 'Diagnosis',
                hint: 'Final or tentative diagnosis...',
              ),
              const SizedBox(height: 24),

              // Follow-up
              const SectionTitle(
                  title: 'Follow-up', icon: Icons.event_note_rounded),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) setState(() => _followupDate = date);
                },
                child: NeuCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          color: AppTheme.primaryTeal, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _followupDate == null
                              ? 'Set Follow-up Date'
                              : DateFormat('MMM d, yyyy')
                                  .format(_followupDate!),
                          style: TextStyle(
                            fontSize: 16,
                            color: _followupDate == null
                                ? AppTheme.textMuted
                                : AppTheme.textColor,
                            fontWeight: _followupDate == null
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_followupDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => setState(() => _followupDate = null),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              NeuTextField(
                controller: _followupNotesController,
                label: 'Follow-up Instructions',
                hint: 'Tests to be done, medications, etc...',
                maxLines: 2,
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: NeuButton(
                  onPressed: _isLoading ? null : _submit,
                  isLoading: _isLoading,
                  child: const Text('SAVE VISIT',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
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

class _PatientPickerSheet extends ConsumerStatefulWidget {
  const _PatientPickerSheet();

  @override
  ConsumerState<_PatientPickerSheet> createState() =>
      _PatientPickerSheetState();
}

class _PatientPickerSheetState extends ConsumerState<_PatientPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(roleAwarePatientsProvider(SearchFilter(
      query: _query,
      healthScheme: HealthSchemeFilter.all,
      priority: PriorityFilter.all,
      dateRange: DateRangeFilter.allTime,
      visitType: VisitTypeFilter.all,
      sortOption: SortOption.nameAsc,
    )));

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text('Select Patient',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          NeuTextField(
            label: 'Search Patient',
            prefixIcon: const Icon(Icons.search),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: patientsAsync.when(
              data: (patients) => ListView.builder(
                itemCount: patients.length,
                itemBuilder: (context, index) {
                  final p = patients[index];
                  return ListTile(
                    title: Text(p['full_name'] ?? 'Unknown'),
                    subtitle: Text(p['phone'] ?? ''),
                    onTap: () => Navigator.pop(
                        context, {'id': p['id'], 'name': p['full_name']}),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
