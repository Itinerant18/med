import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/role_provider.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/features/dr_visits/agents_provider.dart';
import 'package:mediflow/features/followups/followup_provider.dart';
import 'package:mediflow/features/patients/patient_list_provider.dart';

class AddFollowupSheet extends ConsumerStatefulWidget {
  const AddFollowupSheet({
    super.key,
    this.preselectedPatientId,
  });

  final String? preselectedPatientId;

  @override
  ConsumerState<AddFollowupSheet> createState() => _AddFollowupSheetState();
}

class _AddFollowupSheetState extends ConsumerState<AddFollowupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _selectedPatientId;
  String? _selectedPatientName;
  String? _selectedAgentId;
  DateTime? _dueDate;
  String _priority = 'normal';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedPatientId = widget.preselectedPatientId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedPatientId == null) {
      AppSnackbar.showError(context, 'Please select a patient');
      return;
    }
    if (_dueDate == null) {
      AppSnackbar.showError(context, 'Please choose a due date');
      return;
    }

    final authState = ref.read(authNotifierProvider).valueOrNull;
    final isAdmin = ref.read(isAdminProvider);
    final assignedTo =
        isAdmin ? _selectedAgentId : authState?.session.user.id;

    if (assignedTo == null || assignedTo.isEmpty) {
      AppSnackbar.showError(context, 'Please select an agent');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await ref.read(followupTasksProvider.notifier).createTask(
            patientId: _selectedPatientId!,
            assignedTo: assignedTo,
            dueDate: _dueDate!,
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
            title:
                _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
            priority: _priority,
          );

      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'Follow-up task created');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      AppSnackbar.showError(context, AppError.getMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showPatientPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _PatientPickerSheet(),
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
    final isAdmin = ref.watch(isAdminProvider);
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final agentsAsync = ref.watch(agentsProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Center(
                child: Text(
                  'Add Follow-up',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const SectionTitle(
                title: 'Patient',
                icon: Icons.person_search_rounded,
              ),
              GestureDetector(
                onTap: _showPatientPicker,
                child: NeuCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_rounded,
                        color: _selectedPatientId == null
                            ? AppTheme.textMuted
                            : AppTheme.primaryTeal,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedPatientName ??
                              (widget.preselectedPatientId != null
                                  ? 'Selected patient'
                                  : 'Select Patient'),
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
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: AppTheme.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const SectionTitle(
                title: 'Assignment',
                icon: Icons.assignment_ind_outlined,
              ),
              if (isAdmin)
                agentsAsync.when(
                  data: (agents) => NeuCard(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedAgentId,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      hint: const Text('Select Assistant'),
                      items: agents
                          .map(
                            (agent) => DropdownMenuItem(
                              value: agent.id,
                              child: Text(agent.fullName),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedAgentId = value),
                    ),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) =>
                      Text('Error loading assistants: $error'),
                )
              else
                NeuCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        color: AppTheme.primaryTeal,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          authState?.displayName ?? 'Assigned to you',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              const SectionTitle(
                title: 'Task Details',
                icon: Icons.add_task_rounded,
              ),
              NeuTextField(
                controller: _titleCtrl,
                label: 'Title',
                hint: 'Short follow-up title',
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _dueDate = date);
                  }
                },
                child: NeuCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        color: AppTheme.primaryTeal,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _dueDate == null
                              ? 'Set Due Date'
                              : DateFormat('MMM d, yyyy').format(_dueDate!),
                          style: TextStyle(
                            fontSize: 16,
                            color: _dueDate == null
                                ? AppTheme.textMuted
                                : AppTheme.textColor,
                            fontWeight: _dueDate == null
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              NeuCard(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Priority',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Normal'),
                      selected: _priority == 'normal',
                      onSelected: (_) => setState(() => _priority = 'normal'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Urgent'),
                      selected: _priority == 'urgent',
                      onSelected: (_) => setState(() => _priority = 'urgent'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              NeuTextField(
                controller: _notesCtrl,
                label: 'Notes',
                hint: 'Instructions or follow-up details',
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: NeuButton(
                  onPressed: _saving ? null : _submit,
                  isLoading: _saving,
                  child: const Text(
                    'CREATE FOLLOW-UP',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
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
  ConsumerState<_PatientPickerSheet> createState() => _PatientPickerSheetState();
}

class _PatientPickerSheetState extends ConsumerState<_PatientPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(
      roleAwarePatientsProvider(
        SearchFilter(
          query: _query,
          healthScheme: HealthSchemeFilter.all,
          priority: PriorityFilter.all,
          dateRange: DateRangeFilter.allTime,
          visitType: VisitTypeFilter.all,
          sortOption: SortOption.nameAsc,
        ),
      ),
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            'Select Patient',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          NeuTextField(
            label: 'Search Patient',
            prefixIcon: const Icon(Icons.search),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: patientsAsync.when(
              data: (patients) => ListView.builder(
                itemCount: patients.length,
                itemBuilder: (context, index) {
                  final patient = patients[index];
                  return ListTile(
                    title: Text(patient['full_name'] ?? 'Unknown'),
                    subtitle: Text(patient['phone'] ?? ''),
                    onTap: () => Navigator.pop(
                      context,
                      {
                        'id': patient['id'],
                        'name': patient['full_name'],
                      },
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }
}
