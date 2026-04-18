import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FollowupTask {
  final String id;
  final String patientId;
  final String? drVisitId;
  final String assignedTo;
  final String createdBy;
  final DateTime dueDate;
  final String? notes;
  final String status;
  final DateTime? completedAt;
  final DateTime createdAt;

  // Joined field
  final String? patientName;

  FollowupTask({
    required this.id,
    required this.patientId,
    this.drVisitId,
    required this.assignedTo,
    required this.createdBy,
    required this.dueDate,
    this.notes,
    required this.status,
    this.completedAt,
    required this.createdAt,
    this.patientName,
  });

  factory FollowupTask.fromJson(Map<String, dynamic> json) {
    return FollowupTask(
      id: json['id'],
      patientId: json['patient_id'],
      drVisitId: json['dr_visit_id'],
      assignedTo: json['assigned_to'],
      createdBy: json['created_by'],
      dueDate: DateTime.parse(json['due_date']),
      notes: json['notes'],
      status: json['status'],
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      patientName: json['patients']?['full_name'],
    );
  }

  bool get isOverdue => status == 'overdue' || (status == 'pending' && dueDate.isBefore(DateTime.now().subtract(const Duration(days: 0))));
}

final followupTasksProvider = AsyncNotifierProvider<FollowupTasksNotifier, List<FollowupTask>>(
    FollowupTasksNotifier.new);

class FollowupTasksNotifier extends AsyncNotifier<List<FollowupTask>> {
  SupabaseClient get _supabase => ref.read(supabaseClientProvider);

  @override
  Future<List<FollowupTask>> build() async {
    return _fetchTodayTasks();
  }

  Future<List<FollowupTask>> _fetchTodayTasks() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).toIso8601String().split('T')[0];

    // Mark overdue tasks first
    await _markOverdue(user.id, today);

    final response = await _supabase
        .from('followup_tasks')
        .select('*, patients(full_name)')
        .eq('assigned_to', user.id)
        .eq('due_date', today)
        .order('created_at', ascending: false);

    return (response as List).map((json) => FollowupTask.fromJson(json)).toList();
  }

  Future<void> _markOverdue(String userId, String today) async {
    await _supabase
        .from('followup_tasks')
        .update({'status': 'overdue'})
        .eq('assigned_to', userId)
        .eq('status', 'pending')
        .lt('due_date', today);
  }

  Future<void> completeTask(String taskId) async {
    await _supabase.from('followup_tasks').update({
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', taskId);

    ref.invalidateSelf();
  }
}
