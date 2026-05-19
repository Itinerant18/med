import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/features/work_log/work_log_provider.dart';
import 'package:mediflow/models/work_log_model.dart';
import 'package:mediflow/shared/widgets/confirm_dialog.dart';

String _timeAgo(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${diff.inDays ~/ 7}w ago';
  if (diff.inDays < 365) return '${diff.inDays ~/ 30}mo ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}

Color _roleColor(String authorRole) => switch (authorRole) {
      'head_doctor' => AppTheme.primaryTeal,
      'doctor' => AppTheme.doctorAccent,
      _ => AppTheme.assistantAccent,
    };

class WorkLogWidget extends ConsumerStatefulWidget {
  final String entityType;
  final String entityId;
  final String title;

  const WorkLogWidget({
    super.key,
    required this.entityType,
    required this.entityId,
    this.title = 'Activity Log',
  });

  @override
  ConsumerState<WorkLogWidget> createState() => _WorkLogWidgetState();
}

class _WorkLogWidgetState extends ConsumerState<WorkLogWidget> {
  final _bodyCtrl = TextEditingController();
  bool _isSaving = false;

  ({String entityType, String entityId}) get _key =>
      (entityType: widget.entityType, entityId: widget.entityId);

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(workLogProvider(_key).notifier).addLog(
            widget.entityType,
            widget.entityId,
            body,
          );
      _bodyCtrl.clear();
      ref.invalidate(workLogProvider(_key));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteLog(String logId) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete Note',
      message: 'This action cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;

    try {
      await ref.read(workLogProvider(_key).notifier).deleteLog(logId);
      ref.invalidate(workLogProvider(_key));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(e))),
        );
      }
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final logsAsync = ref.watch(workLogProvider(_key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: widget.title,
          icon: AppIcons.edit_note_rounded,
        ),
        NeuTextField(
          controller: _bodyCtrl,
          label: 'Add a note',
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: NeuButton(
            onPressed: _isSaving ? null : _submit,
            isLoading: _isSaving,
            child: const Text('ADD NOTE'),
          ),
        ),
        const SizedBox(height: 20),
        logsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Could not load notes.',
                style: TextStyle(color: AppTheme.errorColor, fontSize: 13),
              ),
            ),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No notes yet',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final canDelete = authState != null &&
                    (authState.session.user.id == entry.authorId ||
                        authState.isHeadDoctor);

                return _LogCard(
                  entry: entry,
                  canDelete: canDelete,
                  onDelete: () => _deleteLog(entry.id),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({
    required this.entry,
    required this.canDelete,
    required this.onDelete,
  });

  final WorkLogEntry entry;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.authorName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _roleColor(entry.authorRole).withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        entry.roleLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _roleColor(entry.authorRole),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _timeAgo(entry.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
              if (canDelete) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    AppIcons.delete_outline_rounded,
                    size: 16,
                    color: AppTheme.errorColor,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  splashRadius: 14,
                  tooltip: 'Delete note',
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            entry.body,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
