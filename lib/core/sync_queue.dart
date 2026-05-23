import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SyncOperation { insert, update, delete }

class SyncAction {
  final String id;
  final String table;
  final SyncOperation operation;
  final Map<String, dynamic> data;
  final String? matchColumn;
  final String? matchValue;
  final DateTime timestamp;
  final int retryCount;

  const SyncAction({
    required this.id,
    required this.table,
    required this.operation,
    required this.data,
    this.matchColumn,
    this.matchValue,
    required this.timestamp,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'table': table,
        'operation': operation.name,
        'data': data,
        'matchColumn': matchColumn,
        'matchValue': matchValue,
        'timestamp': timestamp.toIso8601String(),
        'retryCount': retryCount,
      };

  factory SyncAction.fromJson(Map<String, dynamic> json) => SyncAction(
        id: json['id'] as String,
        table: json['table'] as String,
        operation: SyncOperation.values.byName(json['operation'] as String),
        data: Map<String, dynamic>.from(json['data'] as Map),
        matchColumn: json['matchColumn'] as String?,
        matchValue: json['matchValue'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
        retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      );

  SyncAction withIncrementedRetry() => SyncAction(
        id: id,
        table: table,
        operation: operation,
        data: data,
        matchColumn: matchColumn,
        matchValue: matchValue,
        timestamp: timestamp,
        retryCount: retryCount + 1,
      );
}

/// A queued action that was rejected by the server in a way that cannot
/// succeed by retrying (e.g. RLS denial, validation failure, missing row).
/// Listeners can surface a friendly error to the user and roll back optimistic
/// state.
class SyncPermanentFailure {
  final SyncAction action;
  final Object error;
  const SyncPermanentFailure(this.action, this.error);
}

/// Offline mutation queue backed by SharedPreferences.
///
/// Call [init] once in main(). Enqueue writes when offline; call
/// [processQueue] when connectivity is restored to replay them.
class SyncQueue {
  SyncQueue._();
  static final SyncQueue instance = SyncQueue._();

  static const _queueKey = 'mf_sync_queue';
  static const _maxRetries = 5;

  SharedPreferences? _prefs;
  bool _isProcessing = false;

  final _countController = StreamController<int>.broadcast();
  final _permanentFailureController =
      StreamController<SyncPermanentFailure>.broadcast();

  /// Emits the current count of pending actions whenever it changes.
  Stream<int> get pendingCount => _countController.stream;

  /// Emits an event whenever a queued action is permanently dropped because
  /// the server rejected it with a non-retryable error.
  Stream<SyncPermanentFailure> get permanentFailures =>
      _permanentFailureController.stream;

  int get currentPendingCount => _loadPending().length;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _notifyCount();
  }

  void _notifyCount() => _countController.add(_loadPending().length);

  List<SyncAction> _loadPending() {
    final raw = _prefs?.getString(_queueKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((j) =>
              SyncAction.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _savePending(List<SyncAction> actions) async {
    await _prefs?.setString(
      _queueKey,
      jsonEncode(actions.map((a) => a.toJson()).toList()),
    );
    _notifyCount();
  }

  /// Adds an action to the queue to be synced when connectivity returns.
  Future<void> enqueue(SyncAction action) async {
    final pending = _loadPending();
    pending.add(action);
    await _savePending(pending);
    debugPrint(
        '[SyncQueue] Queued: ${action.operation.name} → ${action.table}');
  }

  /// Drops every queued action without replaying them.
  ///
  /// Must be called on sign-out so the next user on this device cannot
  /// inherit the previous user's pending offline mutations.
  Future<void> clearAll() async {
    await _prefs?.remove(_queueKey);
    _notifyCount();
    debugPrint('[SyncQueue] Cleared all pending actions.');
  }

  /// Replays all pending actions against Supabase.
  /// Actions that fail permanently (>= [_maxRetries]) are dropped.
  /// Safe to call multiple times — ignores concurrent invocations.
  Future<void> processQueue() async {
    if (_isProcessing) return;
    final pending = _loadPending();
    if (pending.isEmpty) return;

    _isProcessing = true;
    debugPrint('[SyncQueue] Processing ${pending.length} action(s)...');

    final client = Supabase.instance.client;
    final remaining = <SyncAction>[];

    for (final action in pending) {
      if (action.retryCount >= _maxRetries) {
        debugPrint(
            '[SyncQueue] Max retries hit, dropping: ${action.id}');
        _permanentFailureController.add(SyncPermanentFailure(
            action, StateError('Max retries exceeded')));
        continue;
      }
      try {
        await _execute(client, action);
        debugPrint(
            '[SyncQueue] Synced: ${action.operation.name} → ${action.table}');
      } catch (e) {
        if (_isPermanentError(e)) {
          debugPrint(
              '[SyncQueue] Permanent failure, dropping: ${action.id}: $e');
          _permanentFailureController.add(SyncPermanentFailure(action, e));
        } else {
          debugPrint('[SyncQueue] Transient failure, retrying ${action.id}: $e');
          remaining.add(action.withIncrementedRetry());
        }
      }
    }

    await _savePending(remaining);
    _isProcessing = false;
    debugPrint(
        '[SyncQueue] Done. ${remaining.length} action(s) still pending.');
  }

  /// Classifies an error as permanent (drop the action) vs transient (retry).
  ///
  /// Permanent: RLS denial, validation, foreign-key violation, missing target,
  /// and any local programming error (StateError / ArgumentError).
  /// Transient: timeouts, socket errors, anything else.
  bool _isPermanentError(Object e) {
    if (e is StateError || e is ArgumentError) return true;
    if (e is PostgrestException) {
      // PostgREST surfaces PG errors via HTTP status as well as PG SQLSTATE.
      // 403 = RLS / permission, 404 = no rows matched, 409 = conflict,
      // 422 = validation. SQLSTATE 23xxx are integrity violations.
      final code = e.code ?? '';
      if (code.startsWith('23')) return true;
      const permanentCodes = {'403', '404', '409', '422', '42501'};
      if (permanentCodes.contains(code)) return true;
    }
    return false;
  }

  Future<void> _execute(SupabaseClient client, SyncAction action) async {
    switch (action.operation) {
      case SyncOperation.insert:
        await client.from(action.table).insert(action.data);
      case SyncOperation.update:
        final col = action.matchColumn;
        final val = action.matchValue;
        if (col == null || val == null) {
          throw StateError('UPDATE missing matchColumn/matchValue');
        }
        await client.from(action.table).update(action.data).eq(col, val);
      case SyncOperation.delete:
        final col = action.matchColumn;
        final val = action.matchValue;
        if (col == null || val == null) {
          throw StateError('DELETE missing matchColumn/matchValue');
        }
        await client.from(action.table).delete().eq(col, val);
    }
  }
}
