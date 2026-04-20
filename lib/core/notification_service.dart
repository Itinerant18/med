import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _notifications
        .initialize(const InitializationSettings(android: android, iOS: ios));
  }

  Future<void> showPatientUpdateNotification({
    required String patientName,
    required String updatedBy,
    required String newStatus,
  }) async {
    final int id = patientName.hashCode;
    const String title = 'Patient Status Updated';
    final String body = '$patientName → $newStatus  (by Dr. $updatedBy)';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mediflow_alerts',
        'MediFlow Alerts',
        importance: Importance.high,
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(id, title, body, details);
  }

  Future<void> showNewPatientNotification({
    required String patientName,
    required String addedBy,
  }) async {
    final int id = patientName.hashCode ^ 'new'.hashCode;
    const String title = 'New Patient Registered';
    final String body = '$patientName added by Dr. $addedBy';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mediflow_alerts',
        'MediFlow Alerts',
        importance: Importance.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(id, title, body, details);
  }

  Future<void> showAppointmentReminder({
    required String patientName,
    required String time,
  }) async {
    final int id = patientName.hashCode ^ 'appointment'.hashCode;
    const String title = 'Upcoming Appointment';
    final String body = '$patientName at $time';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mediflow_alerts',
        'MediFlow Alerts',
        importance: Importance.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(id, title, body, details);
  }

  Future<void> showVisitAssignedNotification({
    required String patientName,
    required String doctorName,
  }) async {
    final int id = patientName.hashCode ^ 'assigned'.hashCode;
    const String title = 'New Visit Assigned';
    final String body = 'Dr. $doctorName assigned you to $patientName';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mediflow_alerts',
        'MediFlow Alerts',
        importance: Importance.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(id, title, body, details);
  }

  Future<void> showFollowupNotification({
    required String patientName,
    required String dueDate,
  }) async {
    final int id = patientName.hashCode ^ 'followup'.hashCode;
    const String title = 'New Follow-up Task';
    final String body = 'Follow-up for $patientName due on $dueDate';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mediflow_alerts',
        'MediFlow Alerts',
        importance: Importance.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(id, title, body, details);
  }

  Future<void> showNewRegistrationNotification({
    required String name,
    required String role,
  }) async {
    final int id = name.hashCode ^ 'registration'.hashCode;
    const String title = 'New Registration Request';
    final String body = '$name wants to join as ${role.replaceAll('_', ' ')}';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mediflow_alerts',
        'MediFlow Alerts',
        importance: Importance.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(id, title, body, details);
  }
}
