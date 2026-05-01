import 'package:flutter/material.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/role_provider.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.targetTable,
    required this.targetId,
    required this.oldData,
    required this.newData,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final String? actorId;
  final String actorName;
  final String actorRole;
  final String action;
  final String targetTable;
  final String? targetId;
  final Map<String, dynamic>? oldData;
  final Map<String, dynamic>? newData;
  final String description;
  final DateTime createdAt;

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'] as String? ?? '',
      actorId: json['actor_id'] as String?,
      actorName: json['actor_name'] as String? ?? 'Unknown',
      actorRole: json['actor_role'] as String? ?? '',
      action: json['action'] as String? ?? '',
      targetTable: json['target_table'] as String? ?? '',
      targetId: json['target_id'] as String?,
      oldData: _mapOrNull(json['old_data']),
      newData: _mapOrNull(json['new_data']),
      description: json['description'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  String get actionLabel {
    switch (action) {
      case 'INSERT':
        return 'Created';
      case 'UPDATE':
        return 'Updated';
      case 'DELETE':
        return 'Deleted';
      case 'APPROVE':
        return 'Approved';
      case 'REJECT':
        return 'Rejected';
      case 'LOGIN':
        return 'Signed In';
      case 'LOGOUT':
        return 'Signed Out';
      default:
        return action.isEmpty ? 'Activity' : _titleCase(action);
    }
  }

  Color get actionColor {
    switch (action) {
      case 'INSERT':
      case 'APPROVE':
        return Colors.green;
      case 'DELETE':
      case 'REJECT':
        return Colors.red;
      case 'UPDATE':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData get actionIcon {
    switch (action) {
      case 'INSERT':
        return AppIcons.add_circle_rounded;
      case 'UPDATE':
        return AppIcons.edit_rounded;
      case 'DELETE':
        return AppIcons.delete_rounded;
      case 'APPROVE':
        return AppIcons.check_circle_rounded;
      case 'REJECT':
        return AppIcons.cancel_rounded;
      case 'LOGIN':
        return AppIcons.login_rounded;
      case 'LOGOUT':
        return AppIcons.logout_rounded;
      default:
        return AppIcons.history_rounded;
    }
  }

  static Map<String, dynamic>? _mapOrNull(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, entryValue) => MapEntry(key.toString(), entryValue),
      );
    }
    return null;
  }

  static String _titleCase(String value) {
    final lower = value.toLowerCase();
    if (lower.isEmpty) return lower;
    return lower[0].toUpperCase() + lower.substring(1);
  }
}

class AuditFilter {
  const AuditFilter({
    this.targetTable = 'all',
    this.actorId,
    this.action = 'all',
    this.dateFrom,
    this.dateTo,
  });

  final String targetTable;
  final String? actorId;
  final String action;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuditFilter &&
        other.targetTable == targetTable &&
        other.actorId == actorId &&
        other.action == action &&
        other.dateFrom == dateFrom &&
        other.dateTo == dateTo;
  }

  @override
  int get hashCode =>
      Object.hash(targetTable, actorId, action, dateFrom, dateTo);
}

class AuditState {
  const AuditState({
    required this.entries,
    required this.hasMore,
    required this.nextCursor,
    required this.nextCursorId,
  });

  final List<AuditLogEntry> entries;
  final bool hasMore;
  final String? nextCursor;
  final String? nextCursorId;
}

final auditLogsProvider =
    AsyncNotifierProvider<AuditNotifier, AuditState>(AuditNotifier.new);

class AuditNotifier extends AsyncNotifier<AuditState> {
  static const _pageSize = 50;

  SupabaseClient get _supabase => ref.read(supabaseClientProvider);
  AuditFilter _filter = const AuditFilter();

  @override
  Future<AuditState> build() async {
    return _fetchPage();
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.entries.isEmpty) {
      return;
    }

    try {
      final lastEntry = current.entries.last;
      final nextPage = await _runFetch(
        cursor: lastEntry.createdAt,
        cursorId: lastEntry.id,
      );

      state = AsyncData(
        AuditState(
          entries: [...current.entries, ...nextPage.entries],
          hasMore: nextPage.hasMore,
          nextCursor: nextPage.nextCursor,
          nextCursorId: nextPage.nextCursorId,
        ),
      );
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchPage);
  }

  Future<void> applyFilter(AuditFilter filter) async {
    _filter = filter;
    await refresh();
  }

  Future<AuditState> _fetchPage() => _runFetch();

  Future<AuditState> _runFetch({
    DateTime? cursor,
    String? cursorId,
  }) async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final isHeadDoctor = ref.read(isHeadDoctorProvider);

    if (authState == null) {
      return const AuditState(
        entries: [],
        hasMore: false,
        nextCursor: null,
        nextCursorId: null,
      );
    }

    try {
      var query = _supabase.from('audit_logs').select();

      if (!isHeadDoctor) {
        query = query.eq('actor_id', authState.session.user.id);
      }

      if (_filter.targetTable != 'all') {
        query = query.eq('target_table', _filter.targetTable);
      }
      if ((_filter.actorId ?? '').isNotEmpty) {
        query = query.eq('actor_id', _filter.actorId!);
      }
      if (_filter.action != 'all') {
        query = query.eq('action', _filter.action);
      }
      if (_filter.dateFrom != null) {
        query = query.gte('created_at', _filter.dateFrom!.toIso8601String());
      }
      if (_filter.dateTo != null) {
        query = query.lte('created_at', _filter.dateTo!.toIso8601String());
      }

      // Composite cursor — (created_at, id). Without the `id` tiebreaker, two
      // rows that share a millisecond would cause `lt` to skip one forever.
      if (cursor != null) {
        final cursorIso = cursor.toIso8601String();
        if (cursorId != null && cursorId.isNotEmpty) {
          query = query.or(
            'created_at.lt.$cursorIso,'
            'and(created_at.eq.$cursorIso,id.lt.$cursorId)',
          );
        } else {
          query = query.lt('created_at', cursorIso);
        }
      }

      final response = await _supabase.retry(() => query
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(_pageSize));

      final rows = (response as List<dynamic>)
          .map((row) => AuditLogEntry.fromJson(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList();

      final last = rows.isEmpty ? null : rows.last;

      return AuditState(
        entries: rows,
        hasMore: rows.length == _pageSize,
        nextCursor: last?.createdAt.toIso8601String(),
        nextCursorId: last?.id,
      );
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }
}

final auditActorsProvider =
    FutureProvider.autoDispose
        .family<List<Map<String, String>>, ({int page, int pageSize})>(
            (ref, pagination) async {
  final supabase = ref.read(supabaseClientProvider);
  final authState = ref.read(authNotifierProvider).valueOrNull;
  final isHeadDoctor = ref.read(isHeadDoctorProvider);

  if (authState == null) return const [];

  try {
    final page = pagination.page < 0 ? 0 : pagination.page;
    final pageSize =
        pagination.pageSize <= 0 ? 25 : pagination.pageSize.clamp(1, 100);
    final start = page * pageSize;
    final end = start + pageSize - 1;

    // Preferred: server-side distinct + minimal PII via RPC.
    try {
      final rpcData = await supabase.retry(() => supabase.rpc(
            'list_audit_actors_minimal',
            params: {
              'p_actor_id': isHeadDoctor ? null : authState.session.user.id,
              'p_limit': pageSize,
              'p_offset': start,
            },
          ));
      return (rpcData as List)
          .map((row) => Map<String, String>.from({
                'actor_id': (row['actor_id'] ?? '').toString(),
                'actor_name': (row['actor_name'] ?? 'Unknown').toString(),
              }))
          .where((a) => (a['actor_id'] ?? '').isNotEmpty)
          .toList(growable: false);
    } catch (_) {}

    // Fallback: minimal fields only, dedup client-side over paged window.
    var query = supabase.from('audit_logs').select('actor_id, actor_name');

    if (!isHeadDoctor) {
      query = query.eq('actor_id', authState.session.user.id);
    }

    final response = await supabase.retry(() => query
        .order('actor_id', ascending: true)
        .order('created_at', ascending: false)
        .range(start, end));
    final seen = <String>{};
    final actors = <Map<String, String>>[];

    for (final row in response as List<dynamic>) {
      final map = Map<String, dynamic>.from(row as Map);
      final actorId = map['actor_id']?.toString();
      final actorName = map['actor_name']?.toString() ?? 'Unknown';
      if (actorId == null || actorId.isEmpty) continue;
      if (!seen.add(actorId)) continue;
      actors.add({
        'actor_id': actorId,
        'actor_name': actorName,
      });
    }

    return actors;
  } catch (e) {
    throw Exception(AppError.getMessage(e));
  }
});

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
