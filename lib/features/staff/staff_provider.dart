import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffMember {
  const StaffMember({
    required this.id,
    required this.fullName,
    required this.specialization,
    required this.email,
    required this.phone,
    required this.role,
    required this.approvalStatus,
    required this.approvedBy,
    required this.approvedAt,
    required this.rejectionReason,
    required this.createdAt,
    required this.phoneVerified,
    required this.fcmToken,
  });

  final String id;
  final String fullName;
  final String specialization;
  final String email;
  final String phone;
  final String role;
  final String approvalStatus;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final DateTime? createdAt;
  final bool phoneVerified;
  final String? fcmToken;

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: (json['id'] ?? '').toString(),
      fullName: (json['full_name'] ?? '').toString(),
      specialization: (json['specialization'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      role: (json['role'] ?? UserRole.assistant.databaseValue).toString(),
      approvalStatus: (json['approval_status'] ?? 'pending').toString(),
      approvedBy: json['approved_by']?.toString(),
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'].toString())
          : null,
      rejectionReason: json['rejection_reason']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      phoneVerified: json['phone_verified'] == true,
      fcmToken: json['fcm_token']?.toString(),
    );
  }

  bool get isActive => approvalStatus == 'approved';
}

class StaffFilter {
  const StaffFilter({
    this.roleFilter,
    this.statusFilter = 'all',
    this.searchQuery = '',
    this.limit = 50,
    this.offset = 0,
  });

  final UserRole? roleFilter;
  final String statusFilter;
  final String searchQuery;
  final int limit;
  final int offset;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StaffFilter &&
        other.roleFilter == roleFilter &&
        other.statusFilter == statusFilter &&
        other.searchQuery == searchQuery &&
        other.limit == limit &&
        other.offset == offset;
  }

  @override
  int get hashCode =>
      Object.hash(roleFilter, statusFilter, searchQuery, limit, offset);
}

final staffListProvider =
    AsyncNotifierProvider<StaffListNotifier, List<StaffMember>>(
        StaffListNotifier.new);

class StaffListNotifier extends AsyncNotifier<List<StaffMember>> {
  SupabaseClient get _supabase => ref.read(supabaseClientProvider);

  @override
  Future<List<StaffMember>> build() async {
    // Watch the auth state so the staff list re-fetches automatically when
    // the current user signs in/out or their role changes — otherwise the
    // list would stay scoped to the previously logged-in user.
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    if (authState?.role != UserRole.headDoctor) {
      return const [];
    }
    return _fetchStaff();
  }

  // Trim the projection to the columns we actually render. Avoids pulling
  // every column on a doctors table that may grow over time.
  static const _staffSelect =
      'id, full_name, specialization, email, phone, role, approval_status, '
      'approved_by, approved_at, rejection_reason, created_at, phone_verified, '
      'fcm_token';

  Future<List<StaffMember>> _fetchStaff() async {
    try {
      final response = await _supabase.retry(() => _supabase
          .from('doctors')
          .select(_staffSelect)
          .order('created_at', ascending: false));

      return (response as List<dynamic>)
          .map((row) =>
              StaffMember.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchForCurrentRole);
  }

  Future<void> updateRole(String doctorId, UserRole newRole) async {
    final actor = _requireHeadDoctor();

    try {
      // IMPORTANT: write the DB value (snake_case), not the Dart enum name.
      // The doctors.role column stores 'head_doctor' / 'doctor' / 'assistant'.
      await _supabase.retry(() => _supabase.from('doctors').update({
            'role': newRole.databaseValue,
          }).eq('id', doctorId));

      await _writeAuditLog(
        actorId: actor.session.user.id,
        actorName: actor.displayName,
        actorRole: actor.role.databaseValue,
        action: 'UPDATE',
        targetId: doctorId,
        description: 'Role updated to ${newRole.databaseValue}',
      );

      await refresh();
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }

  Future<void> suspendAccount(String doctorId) async {
    final actor = _requireHeadDoctor();

    try {
      await _supabase.retry(() => _supabase.from('doctors').update({
            'approval_status': 'rejected',
            'rejection_reason': 'Suspended by admin',
          }).eq('id', doctorId));

      await _writeAuditLog(
        actorId: actor.session.user.id,
        actorName: actor.displayName,
        actorRole: actor.role.databaseValue,
        action: 'UPDATE',
        targetId: doctorId,
        description: 'Account suspended',
      );

      await refresh();
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }

  Future<void> reinstateAccount(String doctorId) async {
    final actor = _requireHeadDoctor();

    try {
      await _supabase.retry(() => _supabase.from('doctors').update({
            'approval_status': 'approved',
            'rejection_reason': null,
          }).eq('id', doctorId));

      await _writeAuditLog(
        actorId: actor.session.user.id,
        actorName: actor.displayName,
        actorRole: actor.role.databaseValue,
        action: 'UPDATE',
        targetId: doctorId,
        description: 'Account reinstated',
      );

      await refresh();
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }

  Future<void> deleteAccount(String doctorId) async {
    final actor = _requireHeadDoctor();
    if (actor.session.user.id == doctorId) {
      throw Exception('You cannot delete your own account.');
    }

    try {
      await _supabase
          .retry(() => _supabase.from('doctors').delete().eq('id', doctorId));

      await _writeAuditLog(
        actorId: actor.session.user.id,
        actorName: actor.displayName,
        actorRole: actor.role.databaseValue,
        action: 'DELETE',
        targetId: doctorId,
        description: 'Staff account deleted from doctors table',
      );

      await refresh();
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }

  AuthUserState _requireHeadDoctor() {
    final actor = ref.read(authNotifierProvider).valueOrNull;
    if (actor?.role != UserRole.headDoctor) {
      throw Exception('Only the head doctor can manage staff.');
    }
    return actor!;
  }

  Future<List<StaffMember>> _fetchForCurrentRole() async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState?.role != UserRole.headDoctor) {
      return const [];
    }
    return _fetchStaff();
  }

  Future<void> _writeAuditLog({
    required String actorId,
    required String actorName,
    required String actorRole,
    required String action,
    required String targetId,
    required String description,
  }) async {
    try {
      await _supabase.retry(() => _supabase.from('audit_logs').insert({
            'actor_id': actorId,
            'actor_name': actorName,
            'actor_role': actorRole,
            'action': action,
            'target_table': 'doctors',
            'target_id': targetId,
            'description': description,
          }));
    } catch (e) {
      // Don't fail the main operation if audit logging fails, but log it.
      debugPrint('Failed to write audit log: $e');
    }
  }
}

final filteredStaffProvider = FutureProvider.autoDispose
    .family<List<StaffMember>, StaffFilter>((ref, filter) async {
  final authState = ref.watch(authNotifierProvider).valueOrNull;
  if (authState?.role != UserRole.headDoctor) {
    return const <StaffMember>[];
  }

  final supabase = ref.read(supabaseClientProvider);
  dynamic queryBuilder =
      supabase.from('doctors').select(StaffListNotifier._staffSelect);

  if (filter.roleFilter != null) {
    queryBuilder = queryBuilder.eq('role', filter.roleFilter!.databaseValue);
  }
  if (filter.statusFilter != 'all') {
    queryBuilder = queryBuilder.eq('approval_status', filter.statusFilter);
  }
  final query = filter.searchQuery.trim();
  if (query.isNotEmpty) {
    final escaped = query.replaceAll(',', r'\,');
    queryBuilder = queryBuilder.or(
      'full_name.ilike.%$escaped%,'
      'email.ilike.%$escaped%,'
      'phone.ilike.%$escaped%,'
      'specialization.ilike.%$escaped%',
    );
  }

  final end = filter.offset + filter.limit - 1;
  final response = await queryBuilder
      .order('created_at', ascending: false)
      .range(filter.offset, end);
  return (response as List<dynamic>)
      .map((row) => StaffMember.fromJson(Map<String, dynamic>.from(row as Map)))
      .toList();
});

class RoleCount {
  final int active;
  final int pending;
  const RoleCount({this.active = 0, this.pending = 0});
  int get total => active + pending;
}

final staffCountByRoleProvider = Provider<Map<String, RoleCount>>((ref) {
  final staff =
      ref.watch(staffListProvider).valueOrNull ?? const <StaffMember>[];
  final counts = <String, RoleCount>{
    'head_doctor': const RoleCount(),
    'doctor': const RoleCount(),
    'assistant': const RoleCount(),
  };

  for (final member in staff) {
    final current = counts[member.role] ?? const RoleCount();
    if (member.approvalStatus == 'approved') {
      counts[member.role] = RoleCount(active: current.active + 1, pending: current.pending);
    } else if (member.approvalStatus == 'pending') {
      counts[member.role] = RoleCount(active: current.active, pending: current.pending + 1);
    }
  }

  return counts;
});
