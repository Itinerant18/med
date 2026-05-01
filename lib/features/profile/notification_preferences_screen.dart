import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/notification_provider.dart';
import 'package:mediflow/core/theme.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  static const _categories = [
    ('patient', 'Patient updates', 'New patients and status changes'),
    ('visit', 'Visit assignments', 'Doctor and agent visit activity'),
    ('followup', 'Follow-ups', 'Tasks, due dates, and review updates'),
    ('system', 'System alerts', 'Account, approval, and app notices'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(notificationPreferencesControllerProvider);
    final preferencesState =
        preferencesAsync.valueOrNull ?? NotificationPreferencesState.defaults;
    final preferences = preferencesState.channelPreferences;
    final quietHoursEnabled = preferencesState.quietHoursEnabled;
    final controller =
        ref.read(notificationPreferencesControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: OrganicBackground(
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: _categories.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            if (index == _categories.length) {
              return NeuCard(
                asymmetricIndex: index,
                child: Row(
                  children: [
                    const OrganicIconContainer(
                      icon: AppIcons.clock,
                      size: 48,
                      iconSize: 18,
                      color: AppTheme.secondary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quiet hours',
                            style: AppTheme.bodyFont(
                                size: 15, weight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Suppress foreground push alerts from 10 PM to 7 AM',
                            style: AppTheme.bodyFont(
                              size: 12,
                              weight: FontWeight.w600,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: quietHoursEnabled,
                      onChanged: preferencesAsync.isLoading
                          ? null
                          : (value) => controller.setQuietHoursEnabled(value),
                    ),
                  ],
                ),
              );
            }

            final (category, title, subtitle) = _categories[index];
            final enabled = preferences[category] ?? true;
            return NeuCard(
              asymmetricIndex: index,
              child: Row(
                children: [
                  OrganicIconContainer(
                    icon: AppIcons.forNotificationCategory(category),
                    size: 48,
                    iconSize: 18,
                    color: enabled ? AppTheme.primaryTeal : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: AppTheme.bodyFont(
                                size: 15, weight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: AppTheme.bodyFont(
                            size: 12,
                            weight: FontWeight.w600,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: preferencesAsync.isLoading
                        ? null
                        : (value) =>
                            controller.setCategoryEnabled(category, value),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
