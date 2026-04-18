import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PendingDoctor {
  final String id;
  final String fullName;
  final String specialization;
  final String email;
  final DateTime createdAt;

  PendingDoctor({
    required this.id,
    required this.fullName,
    required this.specialization,
    required this.email,
    required this.createdAt,
  });

  factory PendingDoctor.fromJson(Map<String, dynamic> json) {
    return PendingDoctor(
      id: json['id'],
      fullName: json['full_name'],
      specialization: json['specialization'],
      email: json['email'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

final pendingApprovalsProvider =
    AsyncNotifierProvider<PendingApprovalsNotifier, List<PendingDoctor>>(
        PendingApprovalsNotifier.new);

class PendingApprovalsNotifier extends AsyncNotifier<List<PendingDoctor>> {
  SupabaseClient get _supabase => ref.read(supabaseClientProvider);

  @override
  Future<List<PendingDoctor>> build() async {
    return _fetchPending();
  }

  Future<List<PendingDoctor>> _fetchPending() async {
    final response = await _supabase
        .from('doctors')
        .select()
        .eq('approval_status', 'pending')
        .order('created_at');

    return (response as List).map((json) => PendingDoctor.fromJson(json)).toList();
  }

  Future<void> approve(String doctorId) async {
    final adminId = _supabase.auth.currentUser?.id;
    await _supabase.from('doctors').update({
      'approval_status': 'approved',
      'approved_by': adminId,
      'approved_at': DateTime.now().toIso8601String(),
    }).eq('id', doctorId);

    state = AsyncData(state.value?.where((d) => d.id != doctorId).toList() ?? []);
  }

  Future<void> reject(String doctorId, String reason) async {
    final adminId = _supabase.auth.currentUser?.id;
    await _supabase.from('doctors').update({
      'approval_status': 'rejected',
      'approved_by': adminId,
      'approved_at': DateTime.now().toIso8601String(),
      'rejection_reason': reason,
    }).eq('id', doctorId);

    state = AsyncData(state.value?.where((d) => d.id != doctorId).toList() ?? []);
  }

  void listenForChanges() {
    _supabase
        .channel('public:doctors')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'doctors',
            callback: (payload) {
              ref.invalidateSelf();
            })
        .subscribe();
  }
}
