// lib/core/notification_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/models/app_notification.dart';

// Single global notification provider (not family)
final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<AppNotification>>(
  (ref) => NotificationNotifier(),
);

final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationProvider).where((n) => !n.isRead).length;
});

final notificationPreferencesProvider =
    StateNotifierProvider<NotificationPreferencesNotifier, Map<String, bool>>(
  (ref) => NotificationPreferencesNotifier(),
);

final quietHoursEnabledProvider = StateProvider<bool>((ref) => false);

class NotificationPreferencesNotifier extends StateNotifier<Map<String, bool>> {
  NotificationPreferencesNotifier()
      : super(const {
          'patient': true,
          'visit': true,
          'followup': true,
          'system': true,
        });

  void setCategoryEnabled(String category, bool enabled) {
    state = {...state, category: enabled};
  }

  bool isEnabled(String category) => state[category] ?? true;
}

class NotificationNotifier extends StateNotifier<List<AppNotification>> {
  NotificationNotifier() : super([]);

  Map<String, bool> _preferences = const {
    'patient': true,
    'visit': true,
    'followup': true,
    'system': true,
  };

  void updatePreferences(Map<String, bool> preferences) {
    _preferences = preferences;
  }

  void addNotification(AppNotification notification) {
    if (!(_preferences[notification.category] ?? true)) return;
    // Avoid duplicate notifications with same ID
    if (state.any((n) => n.id == notification.id)) return;
    state = [notification, ...state];
  }

  void markOneRead(String id) {
    state = [
      for (final notif in state)
        if (notif.id == id) notif.copyWith(isRead: true) else notif,
    ];
  }

  void markAllRead() {
    state = [for (final notif in state) notif.copyWith(isRead: true)];
  }

  void dismiss(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  void clearAll() {
    state = [];
  }
}
