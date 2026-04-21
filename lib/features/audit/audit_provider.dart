import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        return Icons.add_circle_rounded;
      case 'UPDATE':
        return Icons.edit_rounded;
      case 'DELETE':
        return Icons.delete_rounded;
      case 'APPROVE':
        return Icons.check_circle_rounded;
      case 'REJECT':
        return Icons.cancel_rounded;
      case 'LOGIN':
        return Icons.login_rounded;
      case 'LOGOUT':
        return Icons.logout_rounded;
      default:
        return Icons.history_rounded;
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
  });

  final List<AuditLogEntry> entries;
  final bool hasMore;
  final String? nextCursor;
}

final auditLogsProvider =
    AsyncNotifierProvider<AuditNotifier, AuditState>(AuditNotifier.new);

class AuditNotifier extends AsyncNotifier<AuditState> {
  static const _pageSize = 50;

  SupabaseClient get _supabase => ref.read(supabaseClientProvider);
  AuditFilter _filter = const AuditFilter();

  @override
  Future<AuditState> build() async {
    return _fetchPage(reset: true);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.entries.isEmpty) {
      return;
    }

    final lastEntry = current.entries.last;
    final nextPage = await _runFetch(
      reset: false,
      cursor: lastEntry.createdAt,
    );

    state = AsyncData(
      AuditState(
        entries: [...current.entries, ...nextPage.entries],
        hasMore: nextPage.hasMore,
        nextCursor: nextPage.nextCursor,
      ),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchPage(reset: true));
  }

  Future<void> applyFilter(AuditFilter filter) async {
    _filter = filter;
    await refresh();
  }

  Future<AuditState> _fetchPage({required bool reset}) {
    return _runFetch(reset: reset);
  }

  Future<AuditState> _runFetch({
    required bool reset,
    DateTime? cursor,
  }) async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final isHeadDoctor = ref.read(isHeadDoctorProvider);

    if (authState == null) {
      return const AuditState(entries: [], hasMore: false, nextCursor: null);
    }

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
    if (cursor != null) {
      query = query.lt('created_at', cursor.toIso8601String());
    }

    final response =
        await query.order('created_at', ascending: false).limit(_pageSize);
    final rows = (response as List<dynamic>)
        .map((row) => AuditLogEntry.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();

    return AuditState(
      entries: rows,
      hasMore: rows.length == _pageSize,
      nextCursor: rows.isEmpty ? null : rows.last.createdAt.toIso8601String(),
    );
  }
}

final auditActorsProvider =
    FutureProvider.autoDispose<List<Map<String, String>>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final authState = ref.read(authNotifierProvider).valueOrNull;
  final isHeadDoctor = ref.read(isHeadDoctorProvider);

  if (authState == null) return const [];

  var query = supabase.from('audit_logs').select('actor_id, actor_name');

  if (!isHeadDoctor) {
    query = query.eq('actor_id', authState.session.user.id);
  }

  final response = await query.order('actor_name');
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
});

class AuditService {
  static Future<void> log({
    required Ref ref,
    required String action,
    required String targetTable,
    String? targetId,
    String? description,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
  }) async {
    try {
      final authState = ref.read(authNotifierProvider).valueOrNull;
      if (authState == null) return;

      await ref.read(supabaseClientProvider).from('audit_logs').insert({
        'actor_id': authState.session.user.id,
        'actor_name': authState.displayName,
        'actor_role': authState.role.name,
        'action': action,
        'target_table': targetTable,
        'target_id': targetId,
        'old_data': oldData,
        'new_data': newData,
        'description': description,
      });
    } catch (_) {
      // Never bubble audit failures into user-facing flows.
    }
  }
}
