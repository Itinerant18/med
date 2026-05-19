import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/models/work_log_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef WorkLogKey = ({String entityType, String entityId});

const _allowedEntityTypes = <String>{
  'followup_task',
  'agent_outside_visit',
  'dr_visit',
};

/// Reactive provider that fetches the work log entries for a given entity.
final workLogProvider =
    AsyncNotifierProviderFamily<WorkLogNotifier, List<WorkLogEntry>, WorkLogKey>(
  () => WorkLogNotifier(),
);

/// Backward-compatible alias for older call sites.
@Deprecated('Use workLogProvider instead.')
final workLogListProvider = workLogProvider;

/// Family async notifier for the work log thread attached to an entity.
class WorkLogNotifier extends FamilyAsyncNotifier<List<WorkLogEntry>, WorkLogKey> {
  SupabaseClient get _supabase => ref.read(supabaseClientProvider);

  AuthUserState? get _auth => ref.read(authNotifierProvider).valueOrNull;

  @override
  Future<List<WorkLogEntry>> build(WorkLogKey arg) async {
    return fetchLogs(arg.entityType, arg.entityId);
  }

  Future<List<WorkLogEntry>> fetchLogs(
    String entityType,
    String entityId,
  ) async {
    _validateEntityType(entityType);
    _validateEntityId(entityId);

    try {
      final response = await _supabase.retry(() => _supabase
          .from('work_log')
          .select()
          .eq('entity_type', entityType)
          .eq('entity_id', entityId)
          .order('created_at', ascending: false));

      return (response as List<dynamic>)
          .map((row) =>
              WorkLogEntry.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }

  Future<void> addLog(
    String entityType,
    String entityId,
    String body,
  ) async {
    _validateEntityType(entityType);
    _validateEntityId(entityId);

    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw Exception('Log entry cannot be empty.');
    }
    if (trimmed.length > 2000) {
      throw Exception('Log entry is too long (max 2000 characters).');
    }

    final auth = _auth;
    if (auth == null) {
      throw Exception('Not authenticated.');
    }

    try {
      await _supabase.retry(() => _supabase.from('work_log').insert({
            'entity_type': entityType,
            'entity_id': entityId,
            'author_id': auth.session.user.id,
            'author_name': auth.displayName,
            'author_role': auth.role.databaseValue,
            'body': trimmed,
          }));
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }

  Future<void> deleteLog(String logId) async {
    _validateLogId(logId);

    final auth = _auth;
    if (auth == null) {
      throw Exception('Not authenticated.');
    }

    try {
      final existing = await _supabase.retry(() => _supabase
          .from('work_log')
          .select('author_id')
          .eq('id', logId)
          .maybeSingle());

      if (existing == null) {
        throw Exception('Work log entry not found.');
      }

      final authorId = (existing['author_id'] ?? '').toString();
      final isAuthor = authorId == auth.session.user.id;
      if (!isAuthor && !auth.isHeadDoctor) {
        throw Exception('You do not have permission to delete this note.');
      }

      await _supabase
          .retry(() => _supabase.from('work_log').delete().eq('id', logId));
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }

  void _validateEntityType(String entityType) {
    if (entityType.trim().isEmpty) {
      throw Exception('Entity type is required.');
    }
    if (!_allowedEntityTypes.contains(entityType)) {
      throw Exception('Unsupported entity type: $entityType.');
    }
  }

  void _validateEntityId(String entityId) {
    if (entityId.trim().isEmpty) {
      throw Exception('Entity ID is required.');
    }
  }

  void _validateLogId(String logId) {
    if (logId.trim().isEmpty) {
      throw Exception('Log ID is required.');
    }
  }
}
