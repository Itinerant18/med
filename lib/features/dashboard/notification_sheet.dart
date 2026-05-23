import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediflow/shared/widgets/empty_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/notification_provider.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/models/app_notification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationSheet extends ConsumerStatefulWidget {
  const NotificationSheet({super.key});

  @override
  ConsumerState<NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends ConsumerState<NotificationSheet> {
  String _selectedTab = 'All'; // 'All' | 'Unread' | 'Urgent'

  Future<void> _handleTap(
    AppNotification notif,
    NotificationNotifier notifier,
    SupabaseClient supabase,
  ) async {
    // Mark as read in local state and database.
    if (!notif.isRead) {
      await notifier.markOneRead(supabase, notif.id);
    }

    // Navigate if entity info is present.
    if (notif.entityType != null && notif.entityId != null) {
      final route = switch (notif.entityType) {
        'followup_task' => '/followups/review/${notif.entityId}',
        'agent_outside_visit' => '/agent-visits/edit/${notif.entityId}',
        'dr_visit' => '/dr-visits/${notif.entityId}',
        _ => null,
      };
      if (route != null && mounted) {
        Navigator.pop(context);
        context.push(route);
      }
    }
  }

  Future<void> _confirmClearAll(
    BuildContext context,
    NotificationNotifier notifier,
    SupabaseClient supabase,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Clear All Notifications', style: AppTheme.headingFont(size: 18)),
        content: Text(
          'Are you sure you want to delete all notifications? This action cannot be undone.',
          style: AppTheme.bodyFont(size: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted, fontFamily: AppTheme.fontFamily)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await notifier.clearAll(supabase);
    }
  }

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
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationProvider);
    final notifier = ref.read(notificationProvider.notifier);
    final supabase = ref.read(supabaseClientProvider);

    // Apply filtering based on selected tab
    final filteredNotifications = notifications.where((n) {
      if (_selectedTab == 'Unread') {
        return !n.isRead;
      }
      if (_selectedTab == 'Urgent') {
        return n.priority == 'high' || n.priority == 'urgent';
      }
      return true; // 'All'
    }).toList();

    return DraggableScrollableSheet(
      minChildSize: 0.4,
      maxChildSize: 0.9,
      initialChildSize: 0.6,
      builder: (context, scrollController) {
        final entries = <Object>[];
        String? lastLabel;
        for (final notification in filteredNotifications) {
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
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Notifications',
                          style: AppTheme.headingFont(size: 22)),
                      Row(
                        children: [
                          if (notifications.any((n) => !n.isRead)) ...[
                            NeuButton(
                              onPressed: () => notifier.markAllRead(supabase),
                              variant: NeuButtonVariant.ghost,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: const Text(
                                'Mark all read',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          if (notifications.isNotEmpty)
                            IconButton(
                              icon: const Icon(AppIcons.delete_outline_rounded,
                                  color: AppTheme.errorColor, size: 20),
                              tooltip: 'Clear all',
                              onPressed: () => _confirmClearAll(context, notifier, supabase),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Filter Tabs Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Unread', 'Urgent'].map((tab) {
                        final isSelected = _selectedTab == tab;
                        int? count;
                        if (tab == 'Unread') {
                          count = notifications.where((n) => !n.isRead).length;
                        } else if (tab == 'Urgent') {
                          count = notifications
                              .where((n) => n.priority == 'high' || n.priority == 'urgent')
                              .length;
                        }

                        return GestureDetector(
                          onTap: () => setState(() => _selectedTab = tab),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryTeal.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryTeal
                                    : AppTheme.border.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  tab,
                                  style: AppTheme.bodyFont(
                                    size: 13,
                                    weight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? AppTheme.primaryTeal : AppTheme.textMuted,
                                  ),
                                ),
                                if (count != null && count > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.primaryTeal
                                          : AppTheme.textMuted.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      count.toString(),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const OrganicDivider(),
                Expanded(
                  child: filteredNotifications.isEmpty
                      ? EmptyState(
                          icon: AppIcons.notifications_none_rounded,
                          title: switch (_selectedTab) {
                            'Unread' => 'No unread notifications',
                            'Urgent' => 'No urgent alerts',
                            _ => 'No notifications yet',
                          },
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            if (entry is String) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
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
                              onDismiss: () => notifier.dismiss(supabase, notif.id),
                              onTap: () {
                                unawaited(_handleTap(notif, notifier, supabase));
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
            color: notification.isRead
                ? AppTheme.cardBg.withValues(alpha: 0.6)
                : AppTheme.cardBg,
            borderRadius:
                AppTheme.radiusOrganic[index % AppTheme.radiusOrganic.length],
            border: Border(
              left: BorderSide(color: accent, width: notification.isRead ? 3 : 5),
              top: BorderSide(color: AppTheme.border.withValues(alpha: notification.isRead ? 0.3 : 0.6)),
              right: BorderSide(color: AppTheme.border.withValues(alpha: notification.isRead ? 0.3 : 0.6)),
              bottom: BorderSide(color: AppTheme.border.withValues(alpha: notification.isRead ? 0.3 : 0.6)),
            ),
            boxShadow: [
              if (!notification.isRead) AppTheme.shadowSoft,
            ],
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
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  notification.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: notification.isRead
                                        ? AppTheme.textMuted
                                        : AppTheme.foreground,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!notification.isRead) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.errorColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          timeAgo,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textMuted),
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
