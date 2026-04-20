import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/core/role_provider.dart';
import 'package:mediflow/features/dr_visits/dr_visit_provider.dart';
import 'package:mediflow/models/visit_model.dart';
import 'package:mediflow/core/app_snackbar.dart';

class DrVisitDetailScreen extends ConsumerWidget {
  final String visitId;

  const DrVisitDetailScreen({super.key, required this.visitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(drVisitsProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text('Visit Details',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: visitsAsync.when(
        data: (visits) {
          final visit = visits.firstWhere((v) => v.id == visitId,
              orElse: () => throw Exception('Visit not found'));
          return _buildContent(context, ref, visit, isAdmin);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, DrVisit visit, bool isAdmin) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          NeuCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.1),
                  child: const Icon(Icons.person_rounded,
                      color: AppTheme.primaryTeal, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visit.patientName ?? 'Unknown Patient',
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

          // Diagnosis & Notes
          const SectionTitle(
              title: 'Diagnosis & Notes', icon: Icons.description_outlined),
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

          // Follow-up
          const SectionTitle(
              title: 'Follow-up Information', icon: Icons.event_repeat_rounded),
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
                        const Icon(Icons.person_outline,
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

          // Actions
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
                        color: Colors.white, fontWeight: FontWeight.bold)),
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
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status.toLowerCase() == 'completed'
        ? AppTheme.successColor
        : AppTheme.warningColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(
        status.toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
