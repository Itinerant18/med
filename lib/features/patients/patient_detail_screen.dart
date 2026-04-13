import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/patients/patient_provider.dart';
import 'package:mediflow/features/patients/visit_history_provider.dart';
import 'package:mediflow/features/patients/document_upload_widget.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/models/user_role.dart';
import 'package:mediflow/core/app_snackbar.dart';


class PatientDetailScreen extends ConsumerWidget {
  final String patientId;

  const PatientDetailScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientDetailProvider(patientId));
    final visitsAsync = ref.watch(visitHistoryProvider(patientId));
    final authState = ref.watch(authNotifierProvider).value;

    bool canEdit(Map<String, dynamic>? patient) {
      if (authState == null) return false;
      if (authState.role == UserRole.doctor) return true;
      if (patient == null) return false;
      return patient['created_by_id'] == authState.session.user.id;
    }

    bool canDelete(Map<String, dynamic>? patient) {
      return canEdit(patient); // Same rule for now
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: patientAsync.when(
          data: (patient) => Text(patient?['full_name'] ?? 'Patient Details', style: const TextStyle(fontWeight: FontWeight.bold)),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Error'),
        ),
        actions: [
          patientAsync.when(
            data: (patient) => canEdit(patient) 
              ? IconButton(
                  icon: const Icon(Icons.edit, color: AppTheme.primaryTeal),
                  onPressed: () => context.push('/patients/edit/$patientId'),
                )
              : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          patientAsync.when(
            data: (patient) => canDelete(patient)
              ? IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(context, ref, patientId),
                )
              : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: patientAsync.when(
        data: (patient) {
          if (patient == null) return const Center(child: Text('Patient not found'));
          
          final int age = patient['date_of_birth'] != null 
              ? DateTime.now().year - DateTime.parse(patient['date_of_birth']).year
              : 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // TOP SECTION
                NeuCard(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${patient['full_name']} • $age yrs • ${patient['gender'] ?? 'Unknown'}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                            ),
                          ),
                          _buildHealthSchemeBadge(patient['health_scheme']),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(patient['phone'] ?? 'No phone'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.warning, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text('Emergency: ${patient['emergency_contact_number'] ?? 'None'}'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('High Priority', style: TextStyle(fontWeight: FontWeight.bold)),
                        value: patient['is_high_priority'] ?? false,
                        activeThumbColor: Colors.red,
                        onChanged: null, // Read only
                      ),
                      if (patient['staff_comments'] != null && patient['staff_comments'].toString().isNotEmpty) ...[
                        const Divider(height: 24),
                        const Text('Staff Comments:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(patient['staff_comments']),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // CLINICAL INFO CARD
                NeuCard(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Clinical Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
                      const Divider(height: 24),
                      _buildInfoRow('Symptoms', patient['symptoms']),
                      _buildInfoRow('Area Affected', patient['area_affected']),
                      _buildInfoRow('Addictions', patient['addictions']),
                      const SizedBox(height: 12),
                      Text(
                        'Last updated by: Dr. ${patient['last_updated_by'] ?? 'Unknown'} at ${patient['last_updated_at'] != null ? DateFormat('MMM d, yyyy HH:mm').format(DateTime.parse(patient['last_updated_at'])) : 'Unknown'}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // NEW DOCUMENT UPLOAD SECTION
                DocumentUploadWidget(patientId: patientId),
                
                const SizedBox(height: 24),

                // VISIT HISTORY SECTION
                const Text('Visit Timeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
                const SizedBox(height: 16),

                visitsAsync.when(
                  data: (visits) {
                    if (visits.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No past visits found.', style: TextStyle(color: Colors.grey)),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visits.length,
                      itemBuilder: (context, index) {
                        final visit = visits[index];
                        final isLast = index == visits.length - 1;
                        return _buildTimelineItem(visit, isLast);
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Text('Error loading visits: $err'),
                ),
                const SizedBox(height: 80), // Padding for FAB
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryTeal,
        foregroundColor: Colors.white,
        onPressed: () {
          final patient = patientAsync.valueOrNull;
          context.push('/clinical/new', extra: {
            'patientId': patientId,
            'patientName': patient?['full_name'] ?? 'Unknown',
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('New Visit'),
      ),
    );
  }

  Widget _buildHealthSchemeBadge(String? scheme) {
    if (scheme == null || scheme.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryTeal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryTeal),
      ),
      child: Text(scheme.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> visit, bool isLast) {
    final status = visit['patient_flow_status'] ?? visit['test_status'] ?? '';
    Color dotColor = Colors.grey;
    if (status.toLowerCase() == 'completed' || status.toLowerCase() == 'discharged') {
      dotColor = Colors.green;
    } else if (status.toLowerCase() == 'pending' || status.toLowerCase() == 'in progress' || status.toLowerCase() == 'admitted') {
      dotColor = Colors.amber;
    } else if (visit['visit_type']?.toLowerCase() == 'emergency') {
      dotColor = Colors.red;
    }
    
    final dateStr = visit['visit_date'] != null 
        ? DateFormat('MMM d, yyyy • HH:mm').format(DateTime.parse(visit['visit_date']))
        : 'Unknown Date';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline line and dot
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(color: dotColor.withValues(alpha: 0.4), blurRadius: 4, spreadRadius: 1),
                    ]
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          ),
          // Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: NeuCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                          child: Text(visit['visit_type'] ?? 'Unknown', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Complaint: ${visit['chief_complaint'] == 'Other' ? visit['chief_complaint_custom'] : visit['chief_complaint'] ?? 'None'}'),
                    const SizedBox(height: 8),
                    _buildVitalsSummaryRow(visit),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildStatusChip('Tests', visit['tests_performed'] == true ? 'Done' : 'Not required', visit['tests_performed'] == true ? Colors.blue : Colors.grey),
                        _buildStatusChip('OT', visit['ot_required'] == true ? 'Required' : 'Not required', visit['ot_required'] == true ? Colors.red : Colors.grey),
                      ],
                    ),
                    if (visit['final_diagnosis'] != null && visit['final_diagnosis'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Diagnosis: ${visit['final_diagnosis']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                    if (visit['prescriptions'] != null && visit['prescriptions'].toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Rx: ${visit['prescriptions']}', style: const TextStyle(color: AppTheme.primaryTeal)),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('Logged by Dr. ${visit['last_updated_by'] ?? 'Unknown'}', style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsSummaryRow(Map<String, dynamic> visit) {
    final List<String> vitals = [];
    if (visit['bp_systolic'] != null && visit['bp_diastolic'] != null) {
      vitals.add('BP: ${visit['bp_systolic']}/${visit['bp_diastolic']}');
    }
    if (visit['pulse'] != null) vitals.add('P: ${visit['pulse']}');
    if (visit['temperature'] != null) vitals.add('T: ${visit['temperature']}°C');
    if (visit['spo2'] != null) vitals.add('SpO2: ${visit['spo2']}%');
    if (visit['respiratory_rate'] != null) vitals.add('RR: ${visit['respiratory_rate']}');

    if (vitals.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: vitals.map((v) => Text(
          v,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF135043),
          ),
        )).toList(),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String patientId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Patient record'),
        content: const Text('Are you sure you want to delete this patient record? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(patientProvider).deletePatient(patientId);
        if (context.mounted) {
          AppSnackbar.showSuccess(context, 'Patient deleted');
          context.pop();
        }
      } catch (e) {
        if (context.mounted) AppSnackbar.showError(context, 'Failed to delete: $e');
      }
    }
  }

  Widget _buildStatusChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text('$label: $value', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
