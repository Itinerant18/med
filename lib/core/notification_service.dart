import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mediflow/core/app_config.dart';

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

  NotificationDetails _details({String category = 'system'}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        AppConfig.notificationChannelId,
        AppConfig.notificationChannelName,
        importance: Importance.high,
        priority: Priority.high,
        groupKey: 'mediflow.$category',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      ),
      iOS: DarwinNotificationDetails(
        threadIdentifier: 'mediflow.$category',
      ),
    );
  }

  Future<void> showGenericNotification({
    required String title,
    required String body,
    String category = 'system',
    int? id,
  }) async {
    await _notifications.show(
      id ?? Object.hash(title, body, category),
      title,
      body,
      _details(category: category),
    );
  }

  Future<void> showPatientUpdateNotification({
    required String patientName,
    required String updatedBy,
    required String newStatus,
    String category = 'patient',
  }) async {
    await showGenericNotification(
      id: patientName.hashCode,
      title: 'Patient Status Updated',
      body: '$patientName -> $newStatus  (by Dr. $updatedBy)',
      category: category,
    );
  }

  Future<void> showNewPatientNotification({
    required String patientName,
    required String addedBy,
    String category = 'patient',
  }) async {
    await showGenericNotification(
      id: patientName.hashCode ^ 'new'.hashCode,
      title: 'New Patient Registered',
      body: '$patientName added by Dr. $addedBy',
      category: category,
    );
  }

  Future<void> showAppointmentReminder({
    required String patientName,
    required String time,
    String category = 'visit',
  }) async {
    await showGenericNotification(
      id: patientName.hashCode ^ 'appointment'.hashCode,
      title: 'Upcoming Appointment',
      body: '$patientName at $time',
      category: category,
    );
  }

  Future<void> showVisitAssignedNotification({
    required String patientName,
    required String doctorName,
    String category = 'visit',
  }) async {
    await showGenericNotification(
      id: patientName.hashCode ^ 'assigned'.hashCode,
      title: 'New Visit Assigned',
      body: 'Dr. $doctorName assigned you to $patientName',
      category: category,
    );
  }

  Future<void> showFollowupNotification({
    required String patientName,
    required String dueDate,
    String category = 'followup',
  }) async {
    await showGenericNotification(
      id: patientName.hashCode ^ 'followup'.hashCode,
      title: 'New Follow-up Task',
      body: 'Follow-up for $patientName due on $dueDate',
      category: category,
    );
  }

  Future<void> showNewRegistrationNotification({
    required String name,
    required String role,
    String category = 'system',
  }) async {
    await showGenericNotification(
      id: name.hashCode ^ 'registration'.hashCode,
      title: 'New Registration Request',
      body: '$name wants to join as ${role.replaceAll('_', ' ')}',
      category: category,
    );
  }
}
