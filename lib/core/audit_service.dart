import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Singleton audit service that writes to Supabase `audit_logs`.
///
/// Decoupled from Riverpod — callers pass actor info and a [SupabaseClient]
/// directly.  If a write fails the entry is queued in memory and retried on
/// the next [flush] call.
class AuditService {
  AuditService._();
  static final AuditService instance = AuditService._();

  /// In-memory retry queue for entries that failed to write.
  final List<Map<String, dynamic>> _pendingQueue = [];

  /// Number of entries currently waiting for retry.
  int get pendingCount => _pendingQueue.length;

  /// Record an audit entry.  Never throws — failures are logged and queued.
  Future<void> log({
    required SupabaseClient supabase,
    required String actorId,
    required String actorName,
    required String actorRole,
    required String action,
    required String targetTable,
    String? targetId,
    String? description,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
  }) async {
    final payload = <String, dynamic>{
      'actor_id': actorId,
      'actor_name': actorName,
      'actor_role': actorRole,
      'action': action,
      'target_table': targetTable,
      'target_id': targetId,
      'old_data': oldData,
      'new_data': newData,
      'description': description,
    };

    try {
      await supabase.retry(() => supabase.from('audit_logs').insert(payload));
    } catch (e) {
      debugPrint('AuditService.log failed — queued for retry: $e');
      _pendingQueue.add(payload);
    }
  }

  /// Convenience wrapper that reads actor info from the current auth state.
  /// Silently returns if the user is not authenticated.
  Future<void> logFromAuth({
    required Ref ref,
    required String action,
    required String targetTable,
    String? targetId,
    String? description,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
  }) async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState == null) return;

    await log(
      supabase: ref.read(supabaseClientProvider),
      actorId: authState.session.user.id,
      actorName: authState.displayName,
      actorRole: authState.role.databaseValue,
      action: action,
      targetTable: targetTable,
      targetId: targetId,
      description: description,
      oldData: oldData,
      newData: newData,
    );
  }

  /// Retry all queued entries.  Successfully written entries are removed
  /// from the queue; entries that fail again stay queued.
  Future<void> flush(SupabaseClient supabase) async {
    if (_pendingQueue.isEmpty) return;

    final snapshot = List<Map<String, dynamic>>.of(_pendingQueue);
    _pendingQueue.clear();

    for (final entry in snapshot) {
      try {
        await supabase.retry(() => supabase.from('audit_logs').insert(entry));
      } catch (e) {
        debugPrint('AuditService.flush retry failed — re-queuing: $e');
        _pendingQueue.add(entry);
      }
    }
  }
}
