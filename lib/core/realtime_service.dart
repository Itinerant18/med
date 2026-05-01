// lib/core/realtime_service.dart
//
// Per-table Supabase Realtime subscriptions with independent lifecycle,
// exponential backoff retry, and debounced event handlers.
//
// Changes from the previous implementation:
//  • Each table gets its own channel + subscription state (no single flag).
//  • ProviderContainer is no longer retained — callers supply a notification
//    callback that the service stores as a plain function.
//  • Heavy handlers are scheduled via Future.microtask so they don't block
//    the Supabase websocket event loop.
//  • Per-subscription retry with exponential backoff (1s → 2s → 4s … 30s).
//  • Exposes a stream of per-table subscription statuses for UI consumption.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediflow/core/fcm_service.dart';
import 'package:mediflow/core/notification_service.dart';
import 'package:mediflow/models/app_notification.dart';

// ── Public types ────────────────────────────────────────────────────────────

enum SubscriptionStatus { disconnected, connecting, connected, error }

/// Callback the auth gate (or any lifecycle owner) provides so the service
/// can push in-app notifications without holding a ProviderContainer.
typedef OnNotificationCallback = void Function(AppNotification notification);

// ── Internal bookkeeping per table ──────────────────────────────────────────

class _TableSub {
  RealtimeChannel? channel;
  SubscriptionStatus status = SubscriptionStatus.disconnected;
  Timer? retryTimer;
  int retryCount = 0;

  void cancelRetry() {
    retryTimer?.cancel();
    retryTimer = null;
  }

  Duration get nextBackoff {
    final seconds = math.min(1 << retryCount, 30); // 1, 2, 4, … 30
    return Duration(seconds: seconds);
  }
}

// ── Service ─────────────────────────────────────────────────────────────────

class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  /// Tables we subscribe to.
  static const _tables = [
    'patients',
    'visits',
    'dr_visits',
    'followup_tasks',
  ];

  final Map<String, _TableSub> _subs = {};

  String? _currentDoctorName;
  OnNotificationCallback? _onNotification;

  // Status broadcasting.
  final _statusController =
      StreamController<Map<String, SubscriptionStatus>>.broadcast();

  /// Stream of per-table subscription statuses. Emits a new snapshot
  /// whenever any table's status changes.
  Stream<Map<String, SubscriptionStatus>> get statusStream =>
      _statusController.stream;

  /// Current snapshot.
  Map<String, SubscriptionStatus> get currentStatus => {
        for (final e in _subs.entries) e.key: e.value.status,
      };

  // ── Public API ──────────────────────────────────────────────────────────

  /// Start (or re-start) subscriptions for the authenticated user.
  ///
  /// [onNotification] replaces the old ProviderContainer — it's how in-app
  /// notifications reach the UI layer without the service retaining a Ref.
  void subscribeToPatientChanges(
    String currentDoctorName,
    OnNotificationCallback onNotification,
  ) {
    // Skip if already subscribed for this user.
    if (_currentDoctorName == currentDoctorName && _allConnected) {
      _onNotification = onNotification;
      return;
    }

    // Tear down any previous session (user switched / re-auth).
    _unsubscribeAll();

    _currentDoctorName = currentDoctorName;
    _onNotification = onNotification;

    for (final table in _tables) {
      _subscribeTable(table);
    }
  }

  /// Clean teardown — called on logout.
  void dispose() {
    _unsubscribeAll();
    _currentDoctorName = null;
    _onNotification = null;
  }

  // ── Per-table subscription ──────────────────────────────────────────────

  void _subscribeTable(String table) {
    final sub = _subs.putIfAbsent(table, _TableSub.new);
    sub.cancelRetry();
    sub.channel?.unsubscribe();
    _updateStatus(table, SubscriptionStatus.connecting);

    final userId =
        Supabase.instance.client.auth.currentUser?.id ?? 'anon';
    final doctorName = _currentDoctorName ?? '';

    try {
      var builder = Supabase.instance.client
          .channel('mediflow:$table:$userId');

      builder = _attachHandlers(builder, table, doctorName);

      sub.channel = builder.subscribe((status, error) {
        if (error != null) {
          debugPrint('Realtime [$table] error: $error');
          _updateStatus(table, SubscriptionStatus.error);
          _scheduleRetry(table);
        } else if (status == RealtimeSubscribeStatus.subscribed) {
          sub.retryCount = 0;
          _updateStatus(table, SubscriptionStatus.connected);
        }
      });
    } catch (e) {
      debugPrint('Realtime [$table] subscribe failed: $e');
      _updateStatus(table, SubscriptionStatus.error);
      _scheduleRetry(table);
    }
  }

  void _scheduleRetry(String table) {
    final sub = _subs[table];
    if (sub == null) return;
    sub.cancelRetry();
    final delay = sub.nextBackoff;
    sub.retryCount++;
    debugPrint(
        'Realtime [$table] retry #${sub.retryCount} in ${delay.inSeconds}s');
    sub.retryTimer = Timer(delay, () {
      if (_currentDoctorName != null) {
        _subscribeTable(table);
      }
    });
  }

  void _unsubscribeAll() {
    for (final entry in _subs.entries) {
      entry.value.cancelRetry();
      try {
        entry.value.channel?.unsubscribe();
      } catch (_) {}
      entry.value.channel = null;
      entry.value.status = SubscriptionStatus.disconnected;
      entry.value.retryCount = 0;
    }
    _subs.clear();
    _broadcastStatus();
  }

  bool get _allConnected =>
      _subs.isNotEmpty &&
      _subs.values.every((s) => s.status == SubscriptionStatus.connected);

  void _updateStatus(String table, SubscriptionStatus status) {
    final sub = _subs[table];
    if (sub == null) return;
    sub.status = status;
    _broadcastStatus();
  }

  void _broadcastStatus() {
    if (!_statusController.isClosed) {
      _statusController.add(currentStatus);
    }
  }

  // ── Handler wiring ────────────────────────────────────────────────────────

  RealtimeChannel _attachHandlers(
    RealtimeChannel builder,
    String table,
    String doctorName,
  ) {
    switch (table) {
      case 'patients':
        return builder
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'patients',
              callback: (p) => _debounced(() =>
                  _handlePatientUpdate(p, doctorName)),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'patients',
              callback: (p) => _debounced(() =>
                  _handlePatientInsert(p, doctorName)),
            );
      case 'visits':
        return builder.onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'visits',
          callback: (p) => _debounced(() =>
              _handleVisitUpdate(p, doctorName)),
        );
      case 'dr_visits':
        return builder.onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'dr_visits',
          callback: (p) => _debounced(() =>
              _handleDrVisitInsert(p)),
        );
      case 'followup_tasks':
        return builder
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'followup_tasks',
              callback: (p) => _debounced(() =>
                  _handleFollowupTaskInsert(p)),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'followup_tasks',
              callback: (p) => _debounced(() =>
                  _handleFollowupUpdate(p)),
            );
      default:
        return builder;
    }
  }

  /// Schedule handler work as a microtask so the Supabase websocket
  /// callback returns immediately and the event loop isn't blocked.
  void _debounced(void Function() handler) {
    Future.microtask(handler);
  }

  // ── Event handlers ────────────────────────────────────────────────────────

  void _handleDrVisitInsert(PostgresChangePayload payload) {
    try {
      final row = payload.newRecord;
      final assignedAgentId = row['assigned_agent_id']?.toString();
      final currentUserId =
          Supabase.instance.client.auth.currentUser?.id;

      if (assignedAgentId != null && assignedAgentId == currentUserId) {
        _addNotification(
          id: 'visit-${row['id']}',
          title: 'New Visit Assigned',
          body: 'You have been assigned a new patient visit.',
          type: 'visit_assignment',
          category: 'visit',
          priority: 'high',
        );
        NotificationService.instance.showVisitAssignedNotification(
          patientName: 'a patient',
          doctorName: 'your lead',
        );
      } else if (assignedAgentId != null) {
        FcmService.sendToDoctor(
          doctorId: assignedAgentId,
          title: 'New Visit Assigned',
          body: 'A new patient visit has been assigned to you.',
          data: {
            'type': 'visit_assignment',
            'visit_id': row['id']?.toString() ?? '',
          },
        );
      }
    } catch (e) {
      debugPrint('Realtime [dr_visits] handler error: $e');
    }
  }

  void _handleFollowupTaskInsert(PostgresChangePayload payload) {
    final row = payload.newRecord;
    final assignedTo = row['assigned_to']?.toString();
    final currentUserId =
        Supabase.instance.client.auth.currentUser?.id;
    final patientId = row['patient_id']?.toString();
    final dueDate = row['due_date']?.toString() ?? 'soon';
    final taskId = row['id']?.toString() ?? '';
    final title = row['title']?.toString();

    Future<void>(() async {
      String patientName = 'a patient';
      if (patientId != null && patientId.isNotEmpty) {
        try {
          final res = await Supabase.instance.client
              .from('patients')
              .select('full_name')
              .eq('id', patientId)
              .maybeSingle();
          final name = res?['full_name']?.toString();
          if (name != null && name.isNotEmpty) patientName = name;
        } catch (e) {
          debugPrint('followup_task: patient lookup failed: $e');
        }
      }

      if (assignedTo != null && assignedTo == currentUserId) {
        _addNotification(
          id: 'followup-$taskId',
          title: 'New Follow-up Task',
          body: title?.isNotEmpty == true
              ? '$title · $patientName (due $dueDate)'
              : 'Follow-up for $patientName due $dueDate',
          type: 'followup_task',
          category: 'followup',
          priority: 'high',
        );
        NotificationService.instance.showFollowupNotification(
          patientName: patientName,
          dueDate: dueDate,
        );
      } else if (assignedTo != null) {
        FcmService.sendToDoctor(
          doctorId: assignedTo,
          title: 'New Follow-up Task',
          body: 'Follow-up for $patientName due $dueDate',
          data: {'type': 'followup_task', 'task_id': taskId},
        );
      }
    });
  }

  void _handlePatientUpdate(
      PostgresChangePayload payload, String doctorName) {
    try {
      final row = payload.newRecord;
      final updatedBy = row['last_updated_by']?.toString() ?? '';
      final newStatus = row['service_status']?.toString() ?? '';
      final oldStatus =
          payload.oldRecord['service_status']?.toString();

      if (updatedBy == doctorName) return;
      if (newStatus.isEmpty || oldStatus == newStatus) return;

      NotificationService.instance.showPatientUpdateNotification(
        patientName: row['full_name']?.toString() ?? 'A patient',
        updatedBy: updatedBy,
        newStatus: newStatus,
      );
      _addNotification(
        id: 'status-${row['id']}-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Status Updated: ${row['full_name'] ?? 'Patient'}',
        body: '$oldStatus → $newStatus (by $updatedBy)',
        type: 'status_change',
        category: 'patient',
      );
    } catch (e) {
      debugPrint('Realtime [patients/update] handler error: $e');
    }
  }

  void _handlePatientInsert(
      PostgresChangePayload payload, String doctorName) {
    try {
      final row = payload.newRecord;
      final addedBy = row['last_updated_by']?.toString() ?? '';
      if (addedBy.isNotEmpty && addedBy != doctorName) {
        NotificationService.instance.showNewPatientNotification(
          patientName: row['full_name']?.toString() ?? 'A patient',
          addedBy: addedBy,
        );
      }
    } catch (e) {
      debugPrint('Realtime [patients/insert] handler error: $e');
    }
  }

  void _handleVisitUpdate(
      PostgresChangePayload payload, String doctorName) {
    try {
      final row = payload.newRecord;
      final updatedBy = row['last_updated_by']?.toString() ?? '';
      if (updatedBy.isNotEmpty && updatedBy != doctorName) {
        NotificationService.instance.showPatientUpdateNotification(
          patientName: row['patient_name']?.toString() ?? 'A patient',
          updatedBy: updatedBy,
          newStatus:
              row['patient_flow_status']?.toString() ?? 'Updated',
        );
      }
    } catch (e) {
      debugPrint('Realtime [visits/update] handler error: $e');
    }
  }

  void _handleFollowupUpdate(PostgresChangePayload payload) {
    try {
      final row = payload.newRecord;
      final oldStatus = payload.oldRecord['status']?.toString();
      final newStatus = row['status']?.toString();
      final currentUserId =
          Supabase.instance.client.auth.currentUser?.id;
      final createdBy = row['created_by']?.toString();
      final assignedTo = row['assigned_to']?.toString();
      final taskId = row['id']?.toString() ?? '';

      if (newStatus == null ||
          newStatus.isEmpty ||
          oldStatus == newStatus) {
        return;
      }

      // Assistant completed → notify assigning doctor.
      if (newStatus == 'completed' &&
          oldStatus != 'completed' &&
          createdBy == currentUserId &&
          assignedTo != currentUserId) {
        _addNotification(
          id: 'fu-completed-$taskId',
          title: 'Follow-up completed',
          body: 'An assistant completed a follow-up. Tap to review.',
          type: 'followup_review_needed',
          category: 'followup',
          priority: 'urgent',
        );
        NotificationService.instance.showFollowupNotification(
          patientName:
              row['patient_name']?.toString() ?? 'a patient',
          dueDate: 'completed',
        );
        if (createdBy != null && createdBy.isNotEmpty) {
          FcmService.sendToDoctor(
            doctorId: createdBy,
            title: 'Follow-up completed',
            body:
                'An assistant completed a follow-up. Open MediFlow to review.',
            data: {
              'type': 'followup_review_needed',
              'task_id': taskId,
            },
          );
        }
        return;
      }

      // Doctor reviewed → notify assistant.
      if (createdBy == currentUserId) return;
      if (assignedTo != currentUserId) return;

      _addNotification(
        id: 'fu-update-$taskId-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Follow-up Updated',
        body: 'A follow-up task is now: $newStatus',
        type: 'followup_update',
        category: 'followup',
      );
      NotificationService.instance.showFollowupNotification(
        patientName:
            row['patient_name']?.toString() ?? 'a patient',
        dueDate: newStatus,
      );
    } catch (e) {
      debugPrint('Realtime [followup_tasks/update] handler error: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _addNotification({
    required String id,
    required String title,
    required String body,
    required String type,
    String category = 'patient',
    String priority = 'normal',
  }) {
    final cb = _onNotification;
    if (cb == null) return;
    try {
      cb(AppNotification(
        id: id,
        title: title,
        body: body,
        timestamp: DateTime.now(),
        type: type,
        category: category,
        priority: priority,
      ));
    } catch (e) {
      debugPrint('RealtimeService: notification callback failed: $e');
    }
  }
}
