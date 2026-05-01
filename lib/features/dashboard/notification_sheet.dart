import 'package:flutter/material.dart';
import 'package:mediflow/shared/widgets/empty_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/notification_provider.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/models/app_notification.dart';

class NotificationSheet extends ConsumerWidget {
  const NotificationSheet({super.key});

  String _timeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(timestamp);
  }

  String _dateLabel(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(timestamp);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);
    final notifier = ref.read(notificationProvider.notifier);

    return DraggableScrollableSheet(
      minChildSize: 0.4,
      maxChildSize: 0.9,
      initialChildSize: 0.6,
      builder: (context, scrollController) {
        final entries = <Object>[];
        String? lastLabel;
        for (final notification in notifications) {
          final label = _dateLabel(notification.timestamp);
          if (label != lastLabel) {
            entries.add(label);
            lastLabel = label;
          }
          entries.add(notification);
        }

        return OrganicBackground(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.bgColor.withValues(alpha: 0.96),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(
                  top: BorderSide(
                      color: AppTheme.border.withValues(alpha: 0.5))),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Notifications',
                          style: AppTheme.headingFont(size: 22)),
                      if (notifications.any((n) => !n.isRead))
                        NeuButton(
                          onPressed: () => notifier.markAllRead(),
                          variant: NeuButtonVariant.ghost,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: const Text('Mark all read'),
                        ),
                    ],
                  ),
                ),
                const OrganicDivider(),
                Expanded(
                  child: notifications.isEmpty
                      ? const EmptyState(
                          icon: AppIcons.notifications_none_rounded,
                          title: 'No notifications yet',
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            if (entry is String) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                                child: Text(
                                  entry,
                                  style: AppTheme.bodyFont(
                                    size: 12,
                                    weight: FontWeight.w800,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              );
                            }
                            final notif = entry as AppNotification;
                            return _NotificationCard(
                              index: index,
                              notification: notif,
                              timeAgo: _timeAgo(notif.timestamp),
                              onDismiss: () => notifier.dismiss(notif.id),
                              onTap: () {
                                if (!notif.isRead) {
                                  notifier.markOneRead(notif.id);
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.index,
    required this.notification,
    required this.timeAgo,
    required this.onDismiss,
    required this.onTap,
  });

  final int index;
  final AppNotification notification;
  final String timeAgo;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = switch (notification.priority) {
      'urgent' => AppTheme.errorColor,
      'high' => AppTheme.secondary,
      _ => AppTheme.primaryTeal,
    };

    return Dismissible(
      direction: DismissDirection.endToStart,
      key: Key(notification.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(AppIcons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onDismiss(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius:
                AppTheme.radiusOrganic[index % AppTheme.radiusOrganic.length],
            border: Border.all(
              color: notification.isRead
                  ? AppTheme.border.withValues(alpha: 0.5)
                  : accent.withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: const [AppTheme.shadowSoft],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: accent.withValues(
                      alpha: notification.isRead ? 0.08 : 0.14),
                ),
                child: Icon(
                  AppIcons.forNotificationCategory(notification.category),
                  color: accent,
                  size: 17,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: notification.isRead
                                  ? AppTheme.textMuted
                                  : AppTheme.foreground,
                            ),
                          ),
                        ),
                        Text(
                          timeAgo,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 14,
                        color: notification.isRead
                            ? AppTheme.textMuted
                            : AppTheme.foreground.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
