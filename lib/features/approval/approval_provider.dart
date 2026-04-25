import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/notification_service.dart';
import 'package:mediflow/core/parse_utils.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PendingDoctor {
  final String id;
  final String fullName;
  final String specialization;
  final String email;
  final String role;
  final DateTime createdAt;

  PendingDoctor({
    required this.id,
    required this.fullName,
    required this.specialization,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory PendingDoctor.fromJson(Map<String, dynamic> json) {
    return PendingDoctor(
      id: parseDbString(json['id']),
      fullName: parseDbString(json['full_name'], 'Unknown'),
      specialization: parseDbString(json['specialization']),
      email: parseDbString(json['email']),
      role: parseDbString(json['role'], 'doctor'),
      createdAt: parseDbDateOr(json['created_at'], DateTime.now()),
    );
  }
}

final pendingApprovalsProvider =
    AsyncNotifierProvider<PendingApprovalsNotifier, List<PendingDoctor>>(
        PendingApprovalsNotifier.new);

class PendingApprovalsNotifier extends AsyncNotifier<List<PendingDoctor>> {
  SupabaseClient get _supabase => ref.read(supabaseClientProvider);
  RealtimeChannel? _registrationsChannel;
  RealtimeChannel? _statusChangesChannel;

  @override
  Future<List<PendingDoctor>> build() async {
    ref.onDispose(() {
      _registrationsChannel?.unsubscribe();
      _registrationsChannel = null;
      _statusChangesChannel?.unsubscribe();
      _statusChangesChannel = null;
    });
    return _fetchPending();
  }

  Future<List<PendingDoctor>> _fetchPending() async {
    final response = await _supabase
        .from('doctors')
        .select(
            'id, full_name, specialization, email, role, created_at, approval_status')
        .eq('approval_status', 'pending')
        .order('created_at');

    return (response as List)
        .map((json) =>
            PendingDoctor.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  Future<void> approve(String doctorId) async {
    final myRole = ref.read(authNotifierProvider).value?.role;
    if (myRole != UserRole.headDoctor) {
      throw Exception('Only the head doctor can approve registrations.');
    }

    final adminId = _supabase.auth.currentUser?.id;
    await _supabase.from('doctors').update({
      'approval_status': 'approved',
      'approved_by': adminId,
      'approved_at': DateTime.now().toIso8601String(),
    }).eq('id', doctorId);

    state =
        AsyncData(state.value?.where((d) => d.id != doctorId).toList() ?? []);
  }

  Future<void> reject(String doctorId, String reason) async {
    final myRole = ref.read(authNotifierProvider).value?.role;
    if (myRole != UserRole.headDoctor) {
      throw Exception('Only the head doctor can reject registrations.');
    }

    final adminId = _supabase.auth.currentUser?.id;
    await _supabase.from('doctors').update({
      'approval_status': 'rejected',
      'approved_by': adminId,
      'approved_at': DateTime.now().toIso8601String(),
      'rejection_reason': reason,
    }).eq('id', doctorId);

    state =
        AsyncData(state.value?.where((d) => d.id != doctorId).toList() ?? []);
  }

  /// Subscribes to approval-status flips on the doctors table so the head
  /// doctor's pending list refreshes when a row leaves "pending" (approved
  /// elsewhere, rejected, etc.). Idempotent across logins.
  void listenForChanges() {
    _statusChangesChannel?.unsubscribe();
    _statusChangesChannel = _supabase
        .channel('mediflow:doctors:status')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'doctors',
          callback: (payload) {
            final oldStatus =
                payload.oldRecord['approval_status']?.toString();
            final newStatus =
                payload.newRecord['approval_status']?.toString();
            if (oldStatus == newStatus) return;
            ref.invalidateSelf();
          },
        )
        .subscribe();
  }

  void listenForNewRegistrations() {
    _registrationsChannel?.unsubscribe();
    _registrationsChannel = _supabase
        .channel('mediflow:doctors:pending')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'doctors',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'approval_status',
            value: 'pending',
          ),
          callback: (payload) {
            final name =
                payload.newRecord['full_name']?.toString() ?? 'Someone';
            final role = payload.newRecord['role']?.toString() ?? 'doctor';
            NotificationService.instance.showNewRegistrationNotification(
              name: name,
              role: role,
            );
            ref.invalidateSelf();
          },
        )
        .subscribe();
  }
}
