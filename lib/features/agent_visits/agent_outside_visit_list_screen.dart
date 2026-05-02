// lib/features/agent_visits/agent_outside_visit_list_screen.dart
import 'package:flutter/material.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/shared/widgets/skeleton_loader.dart';
import 'package:mediflow/features/agent_visits/agent_outside_visit_provider.dart';
import 'package:mediflow/models/agent_outside_visit_model.dart';
import 'package:mediflow/shared/widgets/empty_state.dart';
import 'package:mediflow/shared/widgets/error_boundary.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/shared/widgets/confirm_dialog.dart';

class AgentOutsideVisitListScreen extends ConsumerWidget {
  const AgentOutsideVisitListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(agentOutsideVisitsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'My External Doctor Visits',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.refresh_rounded),
            tooltip: 'Refresh visits',
            onPressed: () =>
                ref.read(agentOutsideVisitsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: NeuCard(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(AppIcons.info_outline_rounded,
                      color: AppTheme.primaryTeal, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Visits recorded when visiting external specialists for information or with patients referred by them.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryTeal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: visitsAsync.when(
              loading: () => const FollowupListSkeleton(),
              error: (error, stack) => ErrorBoundary(
                error: error,
                stackTrace: stack,
                contextLabel: 'agent_outside_visits',
                title: 'Failed to load external visits',
                onRetry: () => ref
                    .read(agentOutsideVisitsProvider.notifier)
                    .refresh(),
              ),
              data: (visits) {
                if (visits.isEmpty) {
                  return const EmptyState(
                    icon: AppIcons.medical_services_outlined,
                    title: 'No external visits recorded yet',
                    subtitle:
                        'When you accompany a patient to a specialist and record the outcome, it appears here. You can also record visits from a task card in "My Tasks".',
                  );
                }

                return RefreshIndicator(
                  color: AppTheme.primaryTeal,
                  onRefresh: () =>
                      ref.read(agentOutsideVisitsProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: visits.length,
                    itemBuilder: (_, i) => _VisitCard(visit: visits[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-outside-visit',
        backgroundColor: AppTheme.primaryTeal,
        onPressed: () async {
          final result = await context.push<bool>('/agent-visits/new');
          if (result == true) {
            ref.read(agentOutsideVisitsProvider.notifier).refresh();
          }
        },
        icon: const Icon(AppIcons.add_rounded, color: AppTheme.surfaceWhite),
        label: const Text(
          'New External Visit',
          style: TextStyle(color: AppTheme.surfaceWhite, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _VisitCard extends ConsumerWidget {
  final AgentOutsideVisit visit;
  const _VisitCard({required this.visit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeuCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(AppIcons.person_rounded,
                      color: AppTheme.primaryTeal, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visit.patientName != null
                            ? visit.patientName!
                            : visit.extDoctorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        visit.patientName != null
                            ? DateFormat('MMM d, yyyy').format(visit.visitDate)
                            : 'Info collection visit',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: AppTheme.successColor, width: 0.8),
                  ),
                  child: const Text(
                    'RECORDED',
                    style: TextStyle(
                      color: AppTheme.successColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    AppIcons.menu_rounded,
                    color: AppTheme.textMuted,
                  ),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      final result =
                          await context.push<bool>('/agent-visits/edit/${visit.id}');
                      if (result == true) {
                        ref.read(agentOutsideVisitsProvider.notifier).refresh();
                      }
                      return;
                    }

                    final confirmed = await ConfirmDialog.show(
                      context,
                      title: 'Delete External Visit',
                      message:
                          'Are you sure you want to delete this external doctor visit?',
                      confirmLabel: 'Delete',
                      isDestructive: true,
                    );
                    if (confirmed != true || !context.mounted) return;

                    try {
                      await ref
                          .read(agentOutsideVisitsProvider.notifier)
                          .deleteVisit(visit.id);
                      if (context.mounted) {
                        AppSnackbar.showSuccess(
                          context,
                          'External doctor visit deleted successfully',
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        AppSnackbar.showError(
                          context,
                          AppError.getMessage(e),
                        );
                      }
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Icon(AppIcons.local_hospital_outlined,
                    size: 15, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    visit.extDoctorName +
                        (visit.extDoctorSpecialization != null
                            ? ' • ${visit.extDoctorSpecialization}'
                            : '') +
                        (visit.extDoctorHospital != null
                            ? ' · ${visit.extDoctorHospital}'
                            : ''),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (visit.diagnosis != null && visit.diagnosis!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Dx: ${visit.diagnosis}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (visit.followupTaskId != null)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(AppIcons.add_task_rounded,
                        size: 13, color: AppTheme.primaryTeal),
                    SizedBox(width: 6),
                    Text(
                      'Linked to a doctor-assigned task',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.primaryTeal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(AppIcons.info_outline_rounded,
                        size: 13, color: AppTheme.textMuted),
                    SizedBox(width: 6),
                    Text(
                      'Standalone visit',
                      style:
                          TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
