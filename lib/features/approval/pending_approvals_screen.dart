import 'package:flutter/material.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/approval/approval_provider.dart';
import 'package:mediflow/shared/widgets/empty_state.dart';
import 'package:mediflow/shared/widgets/error_boundary.dart';

class PendingApprovalsScreen extends ConsumerStatefulWidget {
  const PendingApprovalsScreen({super.key});

  @override
  ConsumerState<PendingApprovalsScreen> createState() =>
      _PendingApprovalsScreenState();
}

class _PendingApprovalsScreenState
    extends ConsumerState<PendingApprovalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pendingApprovalsProvider.notifier).listenForChanges();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingApprovalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Approvals'),
      ),
      body: pendingAsync.whenWithBoundary(
        contextLabel: 'pending_approvals',
        errorTitle: 'Failed to load pending approvals',
        onRetry: () => ref.invalidate(pendingApprovalsProvider),
        loading: () => const Center(child: CircularProgressIndicator()),
        data: (doctors) {
          if (doctors.isEmpty) {
            return const EmptyState(
              icon: AppIcons.inbox_outlined,
              title: 'No pending approvals',
              subtitle: 'New registrations will appear here for review.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: doctors.length,
            itemBuilder: (context, index) {
              final doctor = doctors[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: NeuCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                AppTheme.primaryTeal.withValues(alpha: 0.1),
                            child: const Icon(AppIcons.person,
                                color: AppTheme.primaryTeal),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doctor.fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  doctor.specialization,
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Email: ${doctor.email}',
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Role: ${doctor.role.replaceAll('_', ' ').toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: NeuButton(
                              onPressed: () =>
                                  _showRejectDialog(context, doctor.id),
                              color: AppTheme.errorColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: const Text('Reject',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: NeuButton(
                              onPressed: () => ref
                                  .read(pendingApprovalsProvider.notifier)
                                  .approve(doctor.id),
                              color: AppTheme.successColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: const Text('Approve',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showRejectDialog(BuildContext context, String doctorId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Registration'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'e.g. Invalid credentials',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(pendingApprovalsProvider.notifier)
                  .reject(doctorId, controller.text);
              Navigator.pop(context);
            },
            child: const Text('Reject',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}
