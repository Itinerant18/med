import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/approval/approval_provider.dart';

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
      body: pendingAsync.when(
        data: (doctors) {
          if (doctors.isEmpty) {
            return const Center(
              child: Text(
                'No pending approvals',
                style: TextStyle(color: AppTheme.textMuted),
              ),
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
                            child: const Icon(Icons.person,
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
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
