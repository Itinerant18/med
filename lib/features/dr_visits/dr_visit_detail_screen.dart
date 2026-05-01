import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/role_provider.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/features/dr_visits/dr_visit_provider.dart';
import 'package:mediflow/features/dr_visits/log_contact_sheet.dart';
import 'package:mediflow/models/visit_model.dart';
import 'package:mediflow/shared/widgets/confirm_dialog.dart';
import 'package:mediflow/shared/widgets/service_status_badge.dart';

class DrVisitDetailScreen extends ConsumerStatefulWidget {
  final String visitId;

  const DrVisitDetailScreen({super.key, required this.visitId});

  @override
  ConsumerState<DrVisitDetailScreen> createState() =>
      _DrVisitDetailScreenState();
}

class _DrVisitDetailScreenState extends ConsumerState<DrVisitDetailScreen> {
  bool _isConverting = false;

  @override
  Widget build(BuildContext context) {
    final visit = ref.watch(drVisitByIdProvider(widget.visitId));
    final visitsAsync = ref.watch(drVisitsProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final currentUserId =
        ref.watch(authNotifierProvider).valueOrNull?.session.user.id;

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text(
          'Visit Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: visitsAsync.when(
        data: (_) {
          if (visit == null) {
            return const Center(
              child: Text(
                'Visit not found',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            );
          }
          return _buildContent(context, visit, isAdmin, currentUserId);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, DrVisit visit, bool isAdmin,
      String? currentUserId) {
    final canConvert =
        (visit.leadStatus == 'new_lead' || visit.leadStatus == 'contacted') &&
            (isAdmin || currentUserId == visit.assignedAgentId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NeuCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.1),
                  child: const Icon(AppIcons.person_rounded,
                      color: AppTheme.primaryTeal, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visit.patientName ??
                            visit.leadPatientName ??
                            'Unknown Patient',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Visit Date: ${DateFormat('MMM d, yyyy · hh:mm a').format(visit.visitDate)}',
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle(
              title: 'Diagnosis & Notes', icon: AppIcons.description_outlined),
          SizedBox(
            width: double.infinity,
            child: NeuCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DIAGNOSIS',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMuted)),
                  const SizedBox(height: 4),
                  Text(
                      visit.diagnosis?.isNotEmpty == true
                          ? visit.diagnosis!
                          : 'No diagnosis recorded',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  const Text('NOTES',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMuted)),
                  const SizedBox(height: 4),
                  Text(
                      visit.visitNotes?.isNotEmpty == true
                          ? visit.visitNotes!
                          : 'No notes recorded',
                      style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (visit.isExternalDoctor) ...[
            const SectionTitle(
              title: 'Referring Doctor',
              icon: AppIcons.local_hospital_outlined,
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: const Border(
                  left: BorderSide(
                    color: AppTheme.warningColor,
                    width: 4,
                  ),
                ),
              ),
              child: NeuCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow(
                      'Name',
                      visit.extDoctorName?.isNotEmpty == true
                          ? visit.extDoctorName!
                          : 'Not provided',
                    ),
                    _detailRow(
                      'Specialization',
                      visit.extDoctorSpecialization?.isNotEmpty == true
                          ? visit.extDoctorSpecialization!
                          : 'Not provided',
                    ),
                    _detailRow(
                      'Hospital',
                      visit.extDoctorHospital?.isNotEmpty == true
                          ? visit.extDoctorHospital!
                          : 'Not provided',
                    ),
                    _detailRow(
                      'Phone',
                      visit.extDoctorPhone?.isNotEmpty == true
                          ? visit.extDoctorPhone!
                          : 'Not provided',
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _LeadSection(
              visit: visit,
              canConvert: canConvert,
              isConverting: _isConverting,
              onLogAttempt: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppTheme.bgColor,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => LogContactSheet(visitId: visit.id),
              ),
              onMarkNotInterested: () async {
                final ok = await ConfirmDialog.show(
                  context,
                  title: 'Mark Not Interested',
                  message:
                      'Mark this lead as not interested? This can be changed later.',
                  confirmLabel: 'Confirm',
                  isDestructive: true,
                );
                if (ok != true) return;
                try {
                  await ref
                      .read(drVisitsProvider.notifier)
                      .updateLeadStatus(visit.id, 'not_interested');
                  if (context.mounted) {
                    AppSnackbar.showSuccess(
                      context,
                      'Lead marked not interested',
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppSnackbar.showError(context, AppError.getMessage(e));
                  }
                }
              },
              onConvert: () async {
                setState(() => _isConverting = true);
                try {
                  await ref
                      .read(drVisitsProvider.notifier)
                      .convertLeadToPatient(visit.id, visit);
                  if (context.mounted) {
                    AppSnackbar.showSuccess(
                        context, 'Patient registered and added to list');
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppSnackbar.showError(context, AppError.getMessage(e));
                  }
                } finally {
                  if (mounted) setState(() => _isConverting = false);
                }
              },
            ),
            const SizedBox(height: 20),
          ],
          const SectionTitle(
              title: 'Follow-up Information',
              icon: AppIcons.event_repeat_rounded),
          SizedBox(
            width: double.infinity,
            child: NeuCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('FOLLOW-UP DATE',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMuted)),
                      const Spacer(),
                      _StatusBadge(status: visit.followupStatus),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    visit.followupDate != null
                        ? DateFormat('MMMM d, yyyy').format(visit.followupDate!)
                        : 'No follow-up date set',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  const Text('FOLLOW-UP NOTES',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMuted)),
                  const SizedBox(height: 4),
                  Text(
                      visit.followupNotes?.isNotEmpty == true
                          ? visit.followupNotes!
                          : 'No follow-up instructions',
                      style: const TextStyle(fontSize: 14)),
                  if (visit.agentName != null) ...[
                    const SizedBox(height: 16),
                    const Text('ASSIGNED TO',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMuted)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(AppIcons.person_outline,
                            size: 16, color: AppTheme.primaryTeal),
                        const SizedBox(width: 8),
                        Text(visit.agentName!,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          if (visit.followupStatus == 'pending')
            SizedBox(
              width: double.infinity,
              child: NeuButton(
                onPressed: () async {
                  await ref
                      .read(drVisitsProvider.notifier)
                      .updateFollowupStatus(visit.id, 'completed');
                  if (context.mounted) {
                    AppSnackbar.showSuccess(
                      context,
                      'Follow-up marked as completed',
                    );
                  }
                },
                child: const Text('MARK FOLLOW-UP COMPLETED',
                    style: TextStyle(
                        color: AppTheme.primaryForeground,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          if (isAdmin && visit.status == 'active') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: NeuButton(
                onPressed: () async {
                  await ref
                      .read(drVisitsProvider.notifier)
                      .updateStatus(visit.id, 'completed');
                  if (context.mounted) {
                    AppSnackbar.showSuccess(
                      context,
                      'Visit marked as completed',
                    );
                  }
                },
                color: AppTheme.successColor,
                child: const Text('COMPLETE VISIT',
                    style: TextStyle(
                        color: AppTheme.primaryForeground,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadSection extends StatelessWidget {
  const _LeadSection({
    required this.visit,
    required this.canConvert,
    required this.isConverting,
    required this.onLogAttempt,
    required this.onMarkNotInterested,
    required this.onConvert,
  });

  final DrVisit visit;
  final bool canConvert;
  final bool isConverting;
  final VoidCallback onLogAttempt;
  final Future<void> Function() onMarkNotInterested;
  final Future<void> Function() onConvert;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          title: 'Patient Lead',
          icon: AppIcons.person_add_rounded,
        ),
        NeuCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _leadRow('Lead Name', visit.leadPatientName ?? 'Not provided'),
              _leadRow('Phone', visit.leadPatientPhone ?? 'Not provided'),
              _leadRow(
                'Address',
                visit.leadPatientAddress ?? 'Not provided',
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _LeadStatusChip(status: visit.leadStatus),
        if (visit.leadNotes?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: const Border(
                left: BorderSide(color: AppTheme.warningColor, width: 4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(AppIcons.assignment_outlined,
                    color: AppTheme.warningColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    visit.leadNotes!,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textColor),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'CONTACT LOG',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        if (visit.contactAttempts.isEmpty)
          const Text(
            'No contact attempts logged yet.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visit.contactAttempts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _ContactAttemptCard(
              attempt: visit.contactAttempts[index],
            ),
          ),
        const SizedBox(height: 16),
        if (visit.leadStatus != 'converted' &&
            visit.leadStatus != 'not_interested')
          SizedBox(
            width: double.infinity,
            child: NeuButton(
              onPressed: onLogAttempt,
              child: const Text(
                'LOG CONTACT ATTEMPT',
                style: TextStyle(
                  color: AppTheme.primaryForeground,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        if (visit.leadStatus != 'converted' &&
            visit.leadStatus != 'not_interested') ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: NeuButton(
              onPressed: onMarkNotInterested,
              variant: NeuButtonVariant.outline,
              color: AppTheme.errorColor,
              child: const Text(
                'MARK NOT INTERESTED',
                style: TextStyle(
                    color: AppTheme.errorColor, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
        if (canConvert) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: NeuButton(
              onPressed: isConverting ? null : onConvert,
              isLoading: isConverting,
              color: AppTheme.successColor,
              child: const Text(
                'CONVERT TO PATIENT',
                style: TextStyle(
                  color: AppTheme.primaryForeground,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _leadRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactAttemptCard extends StatelessWidget {
  const _ContactAttemptCard({required this.attempt});

  final Map<String, dynamic> attempt;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(attempt['date']?.toString() ?? '');
    final method = attempt['method']?.toString() ?? 'other';
    final notes = attempt['notes']?.toString() ?? 'No notes';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeuCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  date != null
                      ? DateFormat('MMM d, yyyy · hh:mm a').format(date)
                      : 'Unknown date',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    method.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryTeal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              notes,
              style: const TextStyle(fontSize: 13, color: AppTheme.textColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return ServiceStatusBadge(status: status);
  }
}

class _LeadStatusChip extends StatelessWidget {
  const _LeadStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return ServiceStatusBadge(status: status);
  }
}
