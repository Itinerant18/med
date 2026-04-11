import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/models/app_notification.dart';

final notificationProviderFamily =
    StateNotifierProvider<NotificationNotifier, List<AppNotification>>(
  (ref) => NotificationNotifier(),
);

final unreadCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationProviderFamily);
  return notifications.where((n) => !n.isRead).length;
});

class NotificationNotifier extends StateNotifier<List<AppNotification>> {
  NotificationNotifier() : super([]);

  void addNotification(AppNotification notification) {
    state = [notification, ...state];
  }

  void markOneRead(String id) {
    state = [
      for (final notif in state)
        if (notif.id == id) notif.copyWith(isRead: true) else notif,
    ];
  }

  void markAllRead() {
    state = [
      for (final notif in state) notif.copyWith(isRead: true),
    ];
  }

  void dismiss(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  void clearAll() {
    state = [];
  }
}
