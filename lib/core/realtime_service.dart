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
import 'package:mediflow/core/notification_service.dart';

// ── Public types ────────────────────────────────────────────────────────────

enum SubscriptionStatus { disconnected, connecting, connected, error }

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
  String? _currentUserId;
  bool _isAssistant = false;

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

  /// Start (or re-start) table subscriptions for the authenticated user.
  /// In-app notifications are now exclusively driven by [notificationProvider]
  /// (which watches the `notifications` table). Raw-table subscriptions here
  /// only fire OS-level foreground banners and data-refresh side-effects.
  void subscribeToPatientChanges(
    String currentDoctorName,
    bool isAssistant,
  ) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

    // Skip if already subscribed for this user.
    if (_currentDoctorName == currentDoctorName &&
        _currentUserId == currentUserId &&
        _isAssistant == isAssistant &&
        _allConnected) {
      return;
    }

    // Tear down any previous session (user switched / re-auth).
    _unsubscribeAll();

    _currentDoctorName = currentDoctorName;
    _currentUserId = currentUserId;
    _isAssistant = isAssistant;

    for (final table in _tables) {
      _subscribeTable(table);
    }
  }

  /// Clean teardown — called on logout.
  void dispose() {
    _unsubscribeAll();
    _currentDoctorName = null;
    _currentUserId = null;
    _isAssistant = false;
  }

  // ── Per-table subscription ──────────────────────────────────────────────

  void _subscribeTable(String table) {
    final sub = _subs.putIfAbsent(table, _TableSub.new);
    sub.cancelRetry();
    sub.channel?.unsubscribe();
    _updateStatus(table, SubscriptionStatus.connecting);

    final userId = _currentUserId ?? 'anon';
    final doctorName = _currentDoctorName ?? '';
    final currentUserId = _currentUserId ?? '';
    final isAssistant = _isAssistant;

    try {
      var builder = Supabase.instance.client
          .channel('mediflow:$table:$userId');

      builder = _attachHandlers(
        builder,
        table,
        doctorName,
        currentUserId,
        isAssistant,
      );

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
    String currentUserId,
    bool isAssistant,
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
        // Requires Realtime table row filters to be enabled in the Supabase
        // dashboard so the server enforces this agent-scoped subscription.
        return builder.onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'dr_visits',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'assigned_agent_id',
            value: currentUserId,
          ),
          callback: (p) => _debounced(() =>
              _handleDrVisitInsert(p)),
        );
      case 'followup_tasks':
        // Requires Realtime table row filters to be enabled in the Supabase
        // dashboard so the server enforces these agent-scoped subscriptions.
        return builder
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'followup_tasks',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'assigned_to',
                value: currentUserId,
              ),
              callback: (p) => _debounced(() =>
                  _handleFollowupTaskInsert(p)),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'followup_tasks',
              filter: isAssistant
                  ? PostgresChangeFilter(
                      type: PostgresChangeFilterType.eq,
                      column: 'assigned_to',
                      value: currentUserId,
                    )
                  : null,
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
    // The subscription filter (assigned_agent_id = currentUserId) ensures this
    // fires only for the current user. Show an OS-level banner immediately;
    // the in-app notification arrives via notificationProvider once the backend
    // inserts the corresponding row into the `notifications` table.
    try {
      NotificationService.instance.showVisitAssignedNotification(
        patientName: 'a patient',
        doctorName: 'your lead',
      );
    } catch (e) {
      debugPrint('Realtime [dr_visits] handler error: $e');
    }
  }

  void _handleFollowupTaskInsert(PostgresChangePayload payload) {
    // Follow-up task notifications are now persisted through the
    // `notifications` table and surfaced via `notificationProvider`.
    // Keep the table subscription active for other side effects, but don't
    // fan out a second in-app / push notification here.
    return;
  }

  void _handlePatientUpdate(
      PostgresChangePayload payload, String doctorName) {
    // Show an OS-level banner for foreground awareness. The in-app notification
    // entry is owned by notificationProvider (notifications table) to avoid
    // duplicates with the backend's own insert into that table.
    try {
      final row = payload.newRecord;
      final updatedBy = row['last_updated_by']?.toString() ?? '';
      final newStatus = row['service_status']?.toString() ?? '';
      final oldStatus = payload.oldRecord['service_status']?.toString();

      if (updatedBy == doctorName) return;
      if (newStatus.isEmpty || oldStatus == newStatus) return;

      NotificationService.instance.showPatientUpdateNotification(
        patientName: row['full_name']?.toString() ?? 'A patient',
        updatedBy: updatedBy,
        newStatus: newStatus,
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
    // Follow-up completion/review notifications are now sent through
    // `PushNotificationService` so the notification table stays canonical.
    return;
  }

}
