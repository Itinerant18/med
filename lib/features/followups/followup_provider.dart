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
  final String? title;
  final String? notes;
  final String priority;
  final bool isExternalDoctor;
  final String? extDoctorName;
  final String? extDoctorSpecialization;
  final String? extDoctorHospital;
  final String? extDoctorPhone;
  final String? completionNotes;
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
    this.title,
    this.notes,
    this.priority = 'normal',
    this.isExternalDoctor = false,
    this.extDoctorName,
    this.extDoctorSpecialization,
    this.extDoctorHospital,
    this.extDoctorPhone,
    this.completionNotes,
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
      title: json['title'],
      notes: json['notes'],
      priority: json['priority'] ?? 'normal',
      isExternalDoctor: json['is_external_doctor'] ?? false,
      extDoctorName: json['ext_doctor_name'],
      extDoctorSpecialization: json['ext_doctor_specialization'],
      extDoctorHospital: json['ext_doctor_hospital'],
      extDoctorPhone: json['ext_doctor_phone'],
      completionNotes: json['completion_notes'],
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
    return _fetchTasks();
  }

  Future<List<FollowupTask>> _fetchTasks() async {
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
        .order('due_date', ascending: true)
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

  Future<void> completeTask(
    String taskId, {
    bool isExternalDoctor = false,
    String? extDoctorName,
    String? extDoctorSpecialization,
    String? extDoctorHospital,
    String? extDoctorPhone,
    String? completionNotes,
  }) async {
    await _supabase.from('followup_tasks').update({
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
      'is_external_doctor': isExternalDoctor,
      'ext_doctor_name': isExternalDoctor ? extDoctorName : null,
      'ext_doctor_specialization':
          isExternalDoctor ? extDoctorSpecialization : null,
      'ext_doctor_hospital': isExternalDoctor ? extDoctorHospital : null,
      'ext_doctor_phone': isExternalDoctor ? extDoctorPhone : null,
      'completion_notes': completionNotes,
    }).eq('id', taskId);

    ref.invalidateSelf();
  }

  Future<void> createTask({
    required String patientId,
    required String assignedTo,
    required DateTime dueDate,
    String? notes,
    String priority = 'normal',
    String? title,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated.');
    }

    await _supabase.from('followup_tasks').insert({
      'patient_id': patientId,
      'assigned_to': assignedTo,
      'created_by': user.id,
      'due_date': dueDate.toIso8601String().split('T')[0],
      'notes': notes,
      'title': title,
      'priority': priority,
      'status': 'pending',
    });

    ref.invalidateSelf();
  }
}
