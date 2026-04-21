// lib/features/patients/patient_detail_screen.dart
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
import 'package:mediflow/features/followups/add_followup_sheet.dart';
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

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: patientAsync.when(
          data: (p) => Text(
            p?['full_name'] ?? 'Patient Details',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Error'),
        ),
        actions: [
          patientAsync.when(
            data: (patient) => canEdit(patient)
                ? Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_task_rounded,
                            color: AppTheme.primaryTeal),
                        tooltip: 'Add Follow-up',
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: AppTheme.bgColor,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (_) =>
                              AddFollowupSheet(preselectedPatientId: patientId),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryTeal),
                        onPressed: () => context.push('/patients/edit/$patientId'),
                        tooltip: 'Edit patient',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                        onPressed: () => _confirmDelete(context, ref),
                        tooltip: 'Delete patient',
                      ),
                    ],
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
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal)),
        error: (err, _) => _buildError(context, err),
        data: (patient) {
          if (patient == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off_rounded, size: 64, color: AppTheme.textMuted),
                  SizedBox(height: 12),
                  Text('Patient not found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }
          return _buildContent(context, ref, patient, visitsAsync);
        },
      ),
      floatingActionButton: patientAsync.hasValue && patientAsync.value != null
          ? FloatingActionButton.extended(
              heroTag: 'patient-detail-new-visit',
              backgroundColor: AppTheme.primaryTeal,
              foregroundColor: Colors.white,
              onPressed: () {
                context.push('/clinical/new', extra: {
                  'patientId': patientId,
                  'patientName': patientAsync.value?['full_name'] ?? 'Unknown',
                });
              },
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('New Visit', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> patient,
    AsyncValue<List<Map<String, dynamic>>> visitsAsync,
  ) {
    final int age = patient['date_of_birth'] != null
        ? DateTime.now().year - DateTime.parse(patient['date_of_birth']).year
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Overview Card ──
          NeuCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: (patient['is_high_priority'] == true)
                            ? Colors.red.withValues(alpha: 0.1)
                            : AppTheme.primaryTeal.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        patient['is_high_priority'] == true
                            ? Icons.priority_high_rounded
                            : Icons.person_rounded,
                        color: patient['is_high_priority'] == true
                            ? Colors.red
                            : AppTheme.primaryTeal,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient['full_name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            [
                              if (age > 0) '$age yrs',
                              if (patient['gender'] != null) patient['gender'],
                              if (patient['blood_group'] != null) patient['blood_group'],
                            ].join(' • '),
                            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (patient['health_scheme'] != null)
                      _SchemeBadge(scheme: patient['health_scheme']),
                  ],
                ),

                if (patient['is_high_priority'] == true) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                        SizedBox(width: 6),
                        Text('HIGH PRIORITY',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.red)),
                      ],
                    ),
                  ),
                ],

                const Divider(height: 24),

                _infoRow(Icons.phone_rounded, 'Phone', patient['phone']),
                _infoRow(Icons.emergency_rounded, 'Emergency', patient['emergency_contact_number']),
                if (patient['email']?.isNotEmpty == true)
                  _infoRow(Icons.email_outlined, 'Email', patient['email']),

                if (patient['staff_comments']?.isNotEmpty == true) ...[
                  const Divider(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.comment_outlined, size: 16, color: AppTheme.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Staff Comments',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                            const SizedBox(height: 3),
                            Text(patient['staff_comments'],
                                style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Clinical Info ──
          NeuCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(title: 'Clinical Information', icon: Icons.medical_services_outlined),
                if (patient['symptoms']?.isNotEmpty == true)
                  _clinicalRow('Symptoms', patient['symptoms']),
                if (patient['area_affected']?.isNotEmpty == true)
                  _clinicalRow('Area Affected', patient['area_affected']),
                if (patient['addictions']?.isNotEmpty == true)
                  _clinicalRow('Addictions', patient['addictions']),
                if (patient['allergies']?.isNotEmpty == true)
                  _clinicalRow('Allergies', patient['allergies']),
                if (patient['existing_conditions']?.isNotEmpty == true)
                  _clinicalRow('Existing Conditions', patient['existing_conditions']),
                if (patient['current_medications']?.isNotEmpty == true)
                  _clinicalRow('Current Medications', patient['current_medications']),
                if (patient['last_updated_by'] != null) ...[
                  const Divider(height: 16),
                  Text(
                    'Last updated by Dr. ${patient['last_updated_by']}'
                    '${patient['last_updated_at'] != null ? ' on ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.parse(patient['last_updated_at']))}' : ''}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Documents ──
          DocumentUploadWidget(patientId: patientId),
          const SizedBox(height: 24),

          // ── Visit Timeline ──
          const Text(
            'Visit Timeline',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.primaryTeal),
          ),
          const SizedBox(height: 12),

          visitsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppTheme.primaryTeal),
              ),
            ),
            error: (err, _) => NeuCard(
              child: Text('Failed to load visits: $err',
                  style: const TextStyle(color: AppTheme.textMuted)),
            ),
            data: (visits) {
              if (visits.isEmpty) {
                return NeuCard(
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.history_rounded, size: 40, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text('No visits recorded yet',
                            style: TextStyle(color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visits.length,
                itemBuilder: (ctx, i) =>
                    _TimelineItem(visit: visits[i], isLast: i == visits.length - 1),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppTheme.textMuted),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _clinicalRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: NeuCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 12),
              const Text('Failed to load patient', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 6),
              Text(error.toString(), style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 16),
              TextButton(onPressed: () => context.pop(), child: const Text('Go Back')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Patient'),
        content: const Text(
          'Are you sure you want to permanently delete this patient record? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(patientProvider).deletePatient(patientId);
        if (context.mounted) {
          AppSnackbar.showSuccess(context, 'Patient deleted successfully');
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          AppSnackbar.showError(context, 'Failed to delete: $e');
        }
      }
    }
  }
}

// ── Scheme Badge ──────────────────────────────────────────────────────────────

class _SchemeBadge extends StatelessWidget {
  final String scheme;
  const _SchemeBadge({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryTeal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryTeal, width: 0.8),
      ),
      child: Text(
        scheme.replaceAll('_', ' ').toUpperCase(),
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.primaryTeal),
      ),
    );
  }
}

// ── Timeline Item ─────────────────────────────────────────────────────────────

class _TimelineItem extends StatelessWidget {
  final Map<String, dynamic> visit;
  final bool isLast;

  const _TimelineItem({required this.visit, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final status = visit['patient_flow_status'] ?? '';
    final dotColor = _dotColor(status, visit['visit_type']);

    final dateStr = visit['visit_date'] != null
        ? DateFormat('MMM d, yyyy • HH:mm').format(DateTime.parse(visit['visit_date']))
        : 'Unknown Date';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: dotColor.withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: NeuCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            visit['visit_type'] ?? 'OPD',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complaint: ${visit['chief_complaint'] == 'Other' ? (visit['chief_complaint_custom'] ?? 'Other') : visit['chief_complaint'] ?? 'Not specified'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),

                    // Vitals row
                    _buildVitals(visit),

                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _statusChip('Tests', visit['tests_performed'] == true ? 'Done' : 'Pending',
                            visit['tests_performed'] == true ? Colors.blue : Colors.grey),
                        _statusChip('OT', visit['ot_required'] == true ? 'Required' : 'Not needed',
                            visit['ot_required'] == true ? Colors.red : Colors.grey),
                        if (status.isNotEmpty)
                          _statusChip('Status', status, AppTheme.primaryTeal),
                      ],
                    ),

                    if (visit['final_diagnosis']?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Dx: ${visit['final_diagnosis']}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                    if (visit['prescriptions']?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Rx: ${visit['prescriptions']}',
                        style: const TextStyle(color: AppTheme.primaryTeal, fontSize: 12),
                      ),
                    ],

                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'by Dr. ${visit['last_updated_by'] ?? 'Unknown'}',
                        style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                      ),
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

  Widget _buildVitals(Map<String, dynamic> visit) {
    final vitals = <String>[];
    if (visit['bp_systolic'] != null && visit['bp_diastolic'] != null) {
      vitals.add('BP: ${visit['bp_systolic']}/${visit['bp_diastolic']}');
    }
    if (visit['pulse'] != null) vitals.add('P: ${visit['pulse']}');
    if (visit['temperature'] != null) vitals.add('T: ${visit['temperature']}°C');
    if (visit['spo2'] != null) vitals.add('SpO₂: ${visit['spo2']}%');
    if (visit['respiratory_rate'] != null) vitals.add('RR: ${visit['respiratory_rate']}');

    if (vitals.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: vitals.map((v) => Text(
          v,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryTeal),
        )).toList(),
      ),
    );
  }

  Widget _statusChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Color _dotColor(String status, String? visitType) {
    final s = status.toLowerCase();
    if (s == 'discharged') return Colors.green;
    if (s == 'admitted' || s == 'under observation') return Colors.amber;
    if (visitType?.toLowerCase() == 'emergency') return Colors.red;
    return Colors.grey;
  }
}
