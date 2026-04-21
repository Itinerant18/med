import 'package:flutter/foundation.dart';
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

  // Safe date parser — handles both "2025-01-15" and "2025-01-15T00:00:00Z".
  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    final str = value.toString();
    if (str.length == 10) {
      final parts = str.split('-');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
    }
    return DateTime.tryParse(str) ?? DateTime.now();
  }

  factory FollowupTask.fromJson(Map<String, dynamic> json) {
    return FollowupTask(
      id: json['id']?.toString() ?? '',
      patientId: json['patient_id']?.toString() ?? '',
      drVisitId: json['dr_visit_id']?.toString(),
      assignedTo: json['assigned_to']?.toString() ?? '',
      createdBy: json['created_by']?.toString() ?? '',
      dueDate: _parseDate(json['due_date']),
      title: json['title']?.toString(),
      notes: json['notes']?.toString(),
      priority: json['priority']?.toString() ?? 'normal',
      isExternalDoctor: json['is_external_doctor'] == true,
      extDoctorName: json['ext_doctor_name']?.toString(),
      extDoctorSpecialization: json['ext_doctor_specialization']?.toString(),
      extDoctorHospital: json['ext_doctor_hospital']?.toString(),
      extDoctorPhone: json['ext_doctor_phone']?.toString(),
      completionNotes: json['completion_notes']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      patientName: json['patients']?['full_name']?.toString(),
    );
  }

  bool get isOverdue {
    if (status == 'overdue') return true;
    if (status == 'pending') {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
      return dueDateOnly.isBefore(todayDate);
    }
    return false;
  }

  bool get isDueToday {
    final today = DateTime.now();
    return dueDate.year == today.year &&
        dueDate.month == today.month &&
        dueDate.day == today.day;
  }
}

// Auto-dispose so the provider re-fetches when the Follow-ups tab is re-entered.
final followupTasksProvider = AsyncNotifierProvider.autoDispose<
    FollowupTasksNotifier, List<FollowupTask>>(FollowupTasksNotifier.new);

class FollowupTasksNotifier
    extends AutoDisposeAsyncNotifier<List<FollowupTask>> {
  SupabaseClient get _supabase => ref.read(supabaseClientProvider);

  @override
  Future<List<FollowupTask>> build() async {
    return _fetchTasks(markOverdue: true);
  }

  Future<List<FollowupTask>> _fetchTasks({bool markOverdue = false}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    if (markOverdue) {
      await _markOverdue(user.id);
    }

    final response = await _supabase
        .from('followup_tasks')
        .select('*, patients(full_name)')
        .eq('assigned_to', user.id)
        .order('due_date', ascending: true)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) =>
            FollowupTask.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  Future<void> _markOverdue(String userId) async {
    try {
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      await _supabase
          .from('followup_tasks')
          .update({'status': 'overdue'})
          .eq('assigned_to', userId)
          .eq('status', 'pending')
          .lt('due_date', todayStr);
    } catch (e) {
      // Non-fatal — continue even if overdue update fails.
      debugPrint('followup _markOverdue error: $e');
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchTasks(markOverdue: true));
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
    if (user == null) throw Exception('Not authenticated.');

    final dueDateStr =
        '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';

    await _supabase.from('followup_tasks').insert({
      'patient_id': patientId,
      'assigned_to': assignedTo,
      'created_by': user.id,
      'due_date': dueDateStr,
      'notes': notes,
      'title': title,
      'priority': priority,
      'status': 'pending',
    });

    ref.invalidateSelf();
  }
}
