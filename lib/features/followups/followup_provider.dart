import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/parse_utils.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
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

  // Doctor-supplied target external doctor info (where to take the patient).
  final String? targetExtDoctorName;
  final String? targetExtDoctorHospital;
  final String? targetExtDoctorSpecialization;
  final String? targetExtDoctorPhone;
  final String? visitInstructions;
  final DateTime? scheduledVisitDate;

  // Assistant-supplied completion details (what actually happened).
  final bool isExternalDoctor;
  final String? extDoctorName;
  final String? extDoctorSpecialization;
  final String? extDoctorHospital;
  final String? extDoctorPhone;
  final String? completionNotes;

  // Doctor review (closes the loop).
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? doctorReviewNotes;

  final String status;
  final DateTime? completedAt;
  final DateTime createdAt;

  // Joined.
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
    this.targetExtDoctorName,
    this.targetExtDoctorHospital,
    this.targetExtDoctorSpecialization,
    this.targetExtDoctorPhone,
    this.visitInstructions,
    this.scheduledVisitDate,
    this.isExternalDoctor = false,
    this.extDoctorName,
    this.extDoctorSpecialization,
    this.extDoctorHospital,
    this.extDoctorPhone,
    this.completionNotes,
    this.reviewedBy,
    this.reviewedAt,
    this.doctorReviewNotes,
    required this.status,
    this.completedAt,
    required this.createdAt,
    this.patientName,
  });

  factory FollowupTask.fromJson(Map<String, dynamic> json) {
    final patients = parseDbMap(json['patients']);
    return FollowupTask(
      id: parseDbString(json['id']),
      patientId: parseDbString(json['patient_id']),
      drVisitId: json['dr_visit_id']?.toString(),
      assignedTo: parseDbString(json['assigned_to']),
      createdBy: parseDbString(json['created_by']),
      dueDate: parseDbDateOr(json['due_date'], DateTime.now()),
      title: json['title']?.toString(),
      notes: json['notes']?.toString(),
      priority: parseDbString(json['priority'], 'normal'),
      targetExtDoctorName: json['target_ext_doctor_name']?.toString(),
      targetExtDoctorHospital: json['target_ext_doctor_hospital']?.toString(),
      targetExtDoctorSpecialization:
          json['target_ext_doctor_specialization']?.toString(),
      targetExtDoctorPhone: json['target_ext_doctor_phone']?.toString(),
      visitInstructions: json['visit_instructions']?.toString(),
      scheduledVisitDate: parseDbDate(json['scheduled_visit_date']),
      isExternalDoctor: json['is_external_doctor'] == true,
      extDoctorName: json['ext_doctor_name']?.toString(),
      extDoctorSpecialization: json['ext_doctor_specialization']?.toString(),
      extDoctorHospital: json['ext_doctor_hospital']?.toString(),
      extDoctorPhone: json['ext_doctor_phone']?.toString(),
      completionNotes: json['completion_notes']?.toString(),
      reviewedBy: json['reviewed_by']?.toString(),
      reviewedAt: parseDbDate(json['reviewed_at']),
      doctorReviewNotes: json['doctor_review_notes']?.toString(),
      status: parseDbString(json['status'], 'pending'),
      completedAt: parseDbDate(json['completed_at']),
      createdAt: parseDbDateOr(json['created_at'], DateTime.now()),
      patientName: patients?['full_name']?.toString(),
    );
  }

  // ── Convenience predicates ─────────────────────────────────────────────

  bool get hasTargetDoctor =>
      (targetExtDoctorName?.isNotEmpty ?? false) ||
      (targetExtDoctorHospital?.isNotEmpty ?? false);

  bool get isReviewed => reviewedAt != null;

  /// True when the assistant has finished the task but the assigning doctor
  /// hasn't yet acknowledged the outcome.
  bool get needsReview => status == 'completed' && !isReviewed;

  bool get isOverdue {
    if (status == 'overdue') return true;
    if (status != 'pending' && status != 'in_progress') return false;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return dueDateOnly.isBefore(todayDate);
  }

  bool get isDueToday {
    final today = DateTime.now();
    return dueDate.year == today.year &&
        dueDate.month == today.month &&
        dueDate.day == today.day;
  }
}

String _dateOnly(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final followupTasksProvider =
    AsyncNotifierProvider.autoDispose<FollowupTasksNotifier, List<FollowupTask>>(
  FollowupTasksNotifier.new,
);

class FollowupTasksNotifier extends AutoDisposeAsyncNotifier<List<FollowupTask>> {
  SupabaseClient get _supabase => ref.read(supabaseClientProvider);
  bool _disposed = false;

  @override
  Future<List<FollowupTask>> build() async {
    _disposed = false;
    final cacheLink = ref.keepAlive();
    ref.listen<AsyncValue<AuthUserState?>>(authNotifierProvider, (prev, next) {
      if (_disposed) return;
      if (next.valueOrNull == null) {
        cacheLink.close();
        ref.invalidateSelf();
      }
    });
    ref.onDispose(() {
      _disposed = true;
      cacheLink.close();
    });

    return _fetchTasks(markOverdue: true);
  }

  Future<List<FollowupTask>> _fetchTasks({bool markOverdue = false}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    if (markOverdue) {
      await _markOverdue(user.id);
    }

    try {
      final response = await _supabase.retry(() => _supabase
          .from('followup_tasks')
          .select('*, patients(full_name)')
          .eq('assigned_to', user.id)
          .order('due_date', ascending: true)
          .order('created_at', ascending: false));

      return (response as List)
          .map((json) =>
              FollowupTask.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }

  Future<void> _markOverdue(String userId) async {
    try {
      final todayStr = _dateOnly(DateTime.now());
      await _supabase.retry(() => _supabase
          .from('followup_tasks')
          .update({'status': 'overdue'})
          .eq('assigned_to', userId)
          .inFilter('status', const ['pending', 'in_progress'])
          .lt('due_date', todayStr));
    } catch (e) {
      // Non-fatal — continue even if overdue update fails.
      debugPrint('followup _markOverdue error: $e');
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchTasks(markOverdue: true));
  }

  /// Move a task into the "in progress" state when the assistant has started
  /// working on it but hasn't completed yet. Best-effort.
  Future<void> markInProgress(String taskId) async {
    try {
      await _supabase.retry(() => _supabase
          .from('followup_tasks')
          .update({'status': 'in_progress'})
          .eq('id', taskId)
          .inFilter('status', const ['pending', 'overdue']));
      ref.invalidateSelf();
    } catch (e) {
      debugPrint('followup markInProgress error: $e');
    }
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
    try {
      await _supabase.retry(() => _supabase.from('followup_tasks').update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
            'is_external_doctor': isExternalDoctor,
            'ext_doctor_name': isExternalDoctor ? extDoctorName : null,
            'ext_doctor_specialization':
                isExternalDoctor ? extDoctorSpecialization : null,
            'ext_doctor_hospital': isExternalDoctor ? extDoctorHospital : null,
            'ext_doctor_phone': isExternalDoctor ? extDoctorPhone : null,
            'completion_notes': completionNotes,
          }).eq('id', taskId));

      ref.invalidateSelf();
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }

  Future<void> createTask({
    required String patientId,
    required String assignedTo,
    required DateTime dueDate,
    String? notes,
    String priority = 'normal',
    String? title,
    // Target external doctor (doctor decides where to send the patient).
    String? targetExtDoctorName,
    String? targetExtDoctorHospital,
    String? targetExtDoctorSpecialization,
    String? targetExtDoctorPhone,
    String? visitInstructions,
    DateTime? scheduledVisitDate,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated.');

    final payload = <String, dynamic>{
      'patient_id': patientId,
      'assigned_to': assignedTo,
      'created_by': user.id,
      'due_date': _dateOnly(dueDate),
      'notes': notes,
      'title': title,
      'priority': priority,
      'status': 'pending',
      if (targetExtDoctorName?.isNotEmpty == true)
        'target_ext_doctor_name': targetExtDoctorName,
      if (targetExtDoctorHospital?.isNotEmpty == true)
        'target_ext_doctor_hospital': targetExtDoctorHospital,
      if (targetExtDoctorSpecialization?.isNotEmpty == true)
        'target_ext_doctor_specialization': targetExtDoctorSpecialization,
      if (targetExtDoctorPhone?.isNotEmpty == true)
        'target_ext_doctor_phone': targetExtDoctorPhone,
      if (visitInstructions?.isNotEmpty == true)
        'visit_instructions': visitInstructions,
      if (scheduledVisitDate != null)
        'scheduled_visit_date': _dateOnly(scheduledVisitDate),
    };

    try {
      await _supabase.retry(() => _supabase.from('followup_tasks').insert(payload));
      ref.invalidateSelf();
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }

  /// Doctor acknowledges a completed follow-up task. Records who reviewed
  /// it, when, and any clinical notes the doctor wants to attach.
  Future<void> reviewTask(
    String taskId, {
    String? reviewNotes,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated.');

    try {
      await _supabase.retry(() => _supabase.from('followup_tasks').update({
            'reviewed_by': user.id,
            'reviewed_at': DateTime.now().toIso8601String(),
            if (reviewNotes != null && reviewNotes.isNotEmpty)
              'doctor_review_notes': reviewNotes,
          }).eq('id', taskId));

      ref.invalidateSelf();
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }
}

// ── Doctor-side queries ──────────────────────────────────────────────────

/// All follow-up tasks the current user *created* (i.e. tasks they assigned
/// to assistants). Used by the doctor follow-ups screen.
final doctorAssignedFollowupsProvider =
    FutureProvider.autoDispose<List<FollowupTask>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return const [];

  try {
    final response = await supabase.retry(() => supabase
        .from('followup_tasks')
        .select('*, patients(full_name)')
        .eq('created_by', user.id)
        .order('due_date', ascending: true)
        .order('created_at', ascending: false));

    return (response as List)
        .map((json) =>
            FollowupTask.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  } catch (e) {
    throw Exception(AppError.getMessage(e));
  }
});

/// Lightweight count of completed-but-unreviewed tasks the current doctor
/// assigned. Powers the "pending reviews" banner on the Dr Visit screen.
final pendingFollowupReviewCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  try {
    final tasks = await ref.read(doctorAssignedFollowupsProvider.future);
    return tasks.where((t) => t.needsReview).length;
  } catch (e) {
    rethrow;
  }
});

/// Single-task fetch for the review screen (loaded by id when the doctor
/// taps "Review" from the dashboard banner or the doctor follow-ups list).
final followupTaskByIdProvider =
    FutureProvider.autoDispose.family<FollowupTask?, String>((ref, id) async {
  if (id.isEmpty) return null;
  final supabase = ref.watch(supabaseClientProvider);
  try {
    final response = await supabase.retry(() => supabase
        .from('followup_tasks')
        .select('*, patients(full_name)')
        .eq('id', id)
        .maybeSingle());
    if (response == null) return null;
    return FollowupTask.fromJson(Map<String, dynamic>.from(response));
  } catch (e) {
    throw Exception(AppError.getMessage(e));
  }
});
