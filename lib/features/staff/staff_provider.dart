import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      specialization: json['specialization'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? UserRole.assistant.databaseValue,
      approvalStatus: json['approval_status'] as String? ?? 'pending',
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      phoneVerified: json['phone_verified'] as bool? ?? false,
      fcmToken: json['fcm_token'] as String?,
    );
  }

  bool get isActive => approvalStatus == 'approved';
}

class StaffFilter {
  const StaffFilter({
    this.roleFilter,
    this.statusFilter = 'all',
    this.searchQuery = '',
  });

  final UserRole? roleFilter;
  final String statusFilter;
  final String searchQuery;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StaffFilter &&
        other.roleFilter == roleFilter &&
        other.statusFilter == statusFilter &&
        other.searchQuery == searchQuery;
  }

  @override
  int get hashCode => Object.hash(roleFilter, statusFilter, searchQuery);
}

final staffListProvider =
    AsyncNotifierProvider<StaffListNotifier, List<StaffMember>>(
        StaffListNotifier.new);

class StaffListNotifier extends AsyncNotifier<List<StaffMember>> {
  SupabaseClient get _supabase => ref.read(supabaseClientProvider);

  @override
  Future<List<StaffMember>> build() async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState?.role != UserRole.headDoctor) {
      return const [];
    }
    return _fetchStaff();
  }

  Future<List<StaffMember>> _fetchStaff() async {
    final response =
        await _supabase.from('doctors').select().order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((row) => StaffMember.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchForCurrentRole);
  }

  Future<void> updateRole(String doctorId, UserRole newRole) async {
    final actor = _requireHeadDoctor();

    await _supabase.from('doctors').update({
      'role': newRole.name,
    }).eq('id', doctorId);

    await _writeAuditLog(
      actorId: actor.session.user.id,
      actorName: actor.displayName,
      actorRole: actor.role.databaseValue,
      action: 'UPDATE',
      targetId: doctorId,
      description: 'Role updated to ${newRole.name}',
    );

    await refresh();
  }

  Future<void> suspendAccount(String doctorId) async {
    final actor = _requireHeadDoctor();

    await _supabase.from('doctors').update({
      'approval_status': 'rejected',
      'rejection_reason': 'Suspended by admin',
    }).eq('id', doctorId);

    await _writeAuditLog(
      actorId: actor.session.user.id,
      actorName: actor.displayName,
      actorRole: actor.role.databaseValue,
      action: 'UPDATE',
      targetId: doctorId,
      description: 'Account suspended',
    );

    await refresh();
  }

  Future<void> reinstateAccount(String doctorId) async {
    final actor = _requireHeadDoctor();

    await _supabase.from('doctors').update({
      'approval_status': 'approved',
      'rejection_reason': null,
    }).eq('id', doctorId);

    await _writeAuditLog(
      actorId: actor.session.user.id,
      actorName: actor.displayName,
      actorRole: actor.role.databaseValue,
      action: 'UPDATE',
      targetId: doctorId,
      description: 'Account reinstated',
    );

    await refresh();
  }

  Future<void> deleteAccount(String doctorId) async {
    final actor = _requireHeadDoctor();
    if (actor.session.user.id == doctorId) {
      throw Exception('You cannot delete your own account.');
    }

    await _supabase.from('doctors').delete().eq('id', doctorId);

    await _writeAuditLog(
      actorId: actor.session.user.id,
      actorName: actor.displayName,
      actorRole: actor.role.databaseValue,
      action: 'DELETE',
      targetId: doctorId,
      description: 'Staff account deleted from doctors table',
    );

    await refresh();
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
    await _supabase.from('audit_logs').insert({
      'actor_id': actorId,
      'actor_name': actorName,
      'actor_role': actorRole,
      'action': action,
      'target_table': 'doctors',
      'target_id': targetId,
      'description': description,
    });
  }
}

final filteredStaffProvider =
    Provider.autoDispose.family<List<StaffMember>, StaffFilter>((ref, filter) {
  final staff = ref.watch(staffListProvider).valueOrNull ?? const <StaffMember>[];

  return staff.where((member) {
    final matchesRole = filter.roleFilter == null
        ? true
        : member.role == filter.roleFilter!.name;
    final matchesStatus = filter.statusFilter == 'all'
        ? true
        : member.approvalStatus == filter.statusFilter;
    final query = filter.searchQuery.trim().toLowerCase();
    final matchesSearch = query.isEmpty ||
        member.fullName.toLowerCase().contains(query) ||
        member.email.toLowerCase().contains(query) ||
        member.phone.toLowerCase().contains(query) ||
        member.specialization.toLowerCase().contains(query);

    return matchesRole && matchesStatus && matchesSearch;
  }).toList();
});

final staffCountByRoleProvider = Provider<Map<String, int>>((ref) {
  final staff = ref.watch(staffListProvider).valueOrNull ?? const <StaffMember>[];
  final counts = <String, int>{
    'head_doctor': 0,
    'doctor': 0,
    'assistant': 0,
  };

  for (final member in staff) {
    counts.update(member.role, (value) => value + 1, ifAbsent: () => 1);
  }

  return counts;
});
