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

  /// Emits the current count of pending actions whenever it changes.
  Stream<int> get pendingCount => _countController.stream;

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
        continue;
      }
      try {
        await _execute(client, action);
        debugPrint(
            '[SyncQueue] Synced: ${action.operation.name} → ${action.table}');
      } catch (e) {
        debugPrint('[SyncQueue] Failed ${action.id}: $e');
        remaining.add(action.withIncrementedRetry());
      }
    }

    await _savePending(remaining);
    _isProcessing = false;
    debugPrint(
        '[SyncQueue] Done. ${remaining.length} action(s) still pending.');
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
