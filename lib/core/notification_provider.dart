// lib/core/notification_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/models/app_notification.dart';

// Single global notification provider (not family)
final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<AppNotification>>(
  (ref) => NotificationNotifier(),
);

// Keep the family alias for backward compatibility
final notificationProviderFamily = notificationProvider;

final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationProvider).where((n) => !n.isRead).length;
});

class NotificationNotifier extends StateNotifier<List<AppNotification>> {
  NotificationNotifier() : super([]);

  void addNotification(AppNotification notification) {
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