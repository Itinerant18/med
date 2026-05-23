import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/cache_service.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/parse_utils.dart';
import 'package:mediflow/core/push_notification_service.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/core/sync_queue.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FollowupTask {
  final String id;
  final String? patientId;
  final String? drVisitId;
  final String assignedTo;
  final String createdBy;
  final DateTime dueDate;
  final String? title;
  final String? notes;
  final String priority;

  // Doctor-supplied target external doctor info (visit destination/context).
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
    this.patientId,
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
      patientId: json['patient_id']?.toString(),
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

  bool get hasPatient => patientId?.trim().isNotEmpty ?? false;

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

  String get displayLabel {
    if (hasPatient && (patientName?.isNotEmpty ?? false)) {
      return patientName!;
    }
    if (title?.isNotEmpty ?? false) return title!;
    if (targetExtDoctorName?.isNotEmpty ?? false) return targetExtDoctorName!;
    return 'External Doctor Visit';
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

    final cacheKey = 'followup_tasks_${user.id}';

    if (markOverdue) {
      await _markOverdue(user.id);
    }

    try {
      final response = await _supabase.retry(() => _supabase
          .from('followup_tasks')
          .select('''
            id,
            patient_id,
            dr_visit_id,
            assigned_to,
            created_by,
            due_date,
            title,
            notes,
            priority,
            target_ext_doctor_name,
            target_ext_doctor_hospital,
            target_ext_doctor_specialization,
            target_ext_doctor_phone,
            visit_instructions,
            scheduled_visit_date,
            is_external_doctor,
            ext_doctor_name,
            ext_doctor_specialization,
            ext_doctor_hospital,
            ext_doctor_phone,
            completion_notes,
            reviewed_by,
            reviewed_at,
            doctor_review_notes,
            status,
            completed_at,
            created_at,
            patients(full_name)
          ''')
          .eq('assigned_to', user.id)
          .order('created_at', ascending: false)
          .order('due_date', ascending: true));

      CacheService.instance
          .putRaw(cacheKey, response, ttl: const Duration(minutes: 30))
          .ignore();

      return (response as List)
          .map((json) =>
              FollowupTask.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
    } catch (e) {
      final cached = CacheService.instance.getRaw(cacheKey);
      if (cached != null) {
        return (cached as List)
            .map((json) =>
                FollowupTask.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();
      }
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
    final updatePayload = {
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
      'is_external_doctor': isExternalDoctor,
      'ext_doctor_name': isExternalDoctor ? extDoctorName : null,
      'ext_doctor_specialization':
          isExternalDoctor ? extDoctorSpecialization : null,
      'ext_doctor_hospital': isExternalDoctor ? extDoctorHospital : null,
      'ext_doctor_phone': isExternalDoctor ? extDoctorPhone : null,
      'completion_notes': completionNotes,
    };

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      await SyncQueue.instance.enqueue(SyncAction(
        id: 'offline_${DateTime.now().millisecondsSinceEpoch}',
        table: 'followup_tasks',
        operation: SyncOperation.update,
        data: updatePayload,
        matchColumn: 'id',
        matchValue: taskId,
        timestamp: DateTime.now(),
        retryCount: 0,
      ));

      // Optimistic: mark the task as completed in current state.
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncData(current.map((t) {
          if (t.id != taskId) return t;
          return FollowupTask(
            id: t.id,
            patientId: t.patientId,
            drVisitId: t.drVisitId,
            assignedTo: t.assignedTo,
            createdBy: t.createdBy,
            dueDate: t.dueDate,
            title: t.title,
            notes: t.notes,
            priority: t.priority,
            targetExtDoctorName: t.targetExtDoctorName,
            targetExtDoctorHospital: t.targetExtDoctorHospital,
            targetExtDoctorSpecialization: t.targetExtDoctorSpecialization,
            targetExtDoctorPhone: t.targetExtDoctorPhone,
            visitInstructions: t.visitInstructions,
            scheduledVisitDate: t.scheduledVisitDate,
            isExternalDoctor: isExternalDoctor,
            extDoctorName: isExternalDoctor ? extDoctorName : t.extDoctorName,
            extDoctorSpecialization: isExternalDoctor
                ? extDoctorSpecialization
                : t.extDoctorSpecialization,
            extDoctorHospital:
                isExternalDoctor ? extDoctorHospital : t.extDoctorHospital,
            extDoctorPhone:
                isExternalDoctor ? extDoctorPhone : t.extDoctorPhone,
            completionNotes: completionNotes,
            reviewedBy: t.reviewedBy,
            reviewedAt: t.reviewedAt,
            doctorReviewNotes: t.doctorReviewNotes,
            status: 'completed',
            completedAt: DateTime.now(),
            createdAt: t.createdAt,
            patientName: t.patientName,
          );
        }).toList());
      }
      return;
    }

    try {
      await _supabase.retry(() => _supabase
          .from('followup_tasks')
          .update(updatePayload)
          .eq('id', taskId));

      ref.invalidateSelf();

      // ── Push notification to task creator ──
      try {
        final taskRes = await _supabase
            .from('followup_tasks')
            .select('created_by')
            .eq('id', taskId)
            .maybeSingle();
        final createdBy = taskRes?['created_by']?.toString();
        if (createdBy != null) {
          await PushNotificationService.sendNotification(
            ref: ref,
            event: 'followup_completed',
            recipientIds: [createdBy],
            title: 'Task completed',
            body: 'Your follow-up task has been completed by the agent',
            data: {
              'entityType': 'followup_task',
              'entityId': taskId,
            },
          );
        }
      } catch (_) {
        // Best-effort.
      }
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }

  Future<void> createTask({
    String? patientId,
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

    final normalizedPatientId = patientId?.trim();
    final normalizedTitle = title?.trim();
    final effectiveTitle = (normalizedTitle?.isNotEmpty ?? false)
        ? normalizedTitle
        : (normalizedPatientId == null || normalizedPatientId.isEmpty)
            ? _defaultVisitTitle(targetExtDoctorName)
            : null;

    final payload = <String, dynamic>{
      'assigned_to': assignedTo,
      'created_by': user.id,
      'due_date': _dateOnly(dueDate),
      'notes': notes,
      'priority': priority,
      'status': 'pending',
      if (normalizedPatientId != null && normalizedPatientId.isNotEmpty)
        'patient_id': normalizedPatientId,
      if (effectiveTitle != null && effectiveTitle.isNotEmpty)
        'title': effectiveTitle,
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
      final insertedTask = await _supabase.retry(() => _supabase
          .from('followup_tasks')
          .insert(payload)
          .select('id')
          .maybeSingle());
      final createdTaskId = insertedTask?['id']?.toString();
      ref.invalidateSelf();

      // ── Push notification to assigned agent ──
      try {
        final hasPatient = normalizedPatientId != null && normalizedPatientId.isNotEmpty;
        String? patientName;
        if (hasPatient) {
          final patientRes = await _supabase
              .from('patients')
              .select('full_name')
              .eq('id', normalizedPatientId)
              .maybeSingle();
          patientName = patientRes?['full_name']?.toString();
        }
        await PushNotificationService.sendNotification(
          ref: ref,
          event: 'followup_assigned',
          recipientIds: [assignedTo],
          title: hasPatient ? 'New task assigned' : 'New visit assigned',
          body: hasPatient
              ? 'Take ${patientName ?? "patient"} to ${targetExtDoctorName ?? "external doctor"}'
              : 'Visit ${targetExtDoctorName ?? "external doctor"}',
          data: {
            'entityType': 'followup_task',
            if (createdTaskId != null && createdTaskId.isNotEmpty)
              'entityId': createdTaskId,
            'priority': priority,
          },
        );
      } catch (_) {
        // Best-effort — notification failure must not break task creation.
      }
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }

  String _defaultVisitTitle(String? targetExtDoctorName) {
    final name = targetExtDoctorName?.trim();
    if (name == null || name.isEmpty) {
      return 'External Doctor Visit';
    }
    return 'External Doctor Visit - $name';
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

      // ── Push notification to assigned agent ──
      try {
        final taskRes = await _supabase
            .from('followup_tasks')
            .select('assigned_to')
            .eq('id', taskId)
            .maybeSingle();
        final assignedTo = taskRes?['assigned_to']?.toString();
        if (assignedTo != null) {
          await PushNotificationService.sendNotification(
            ref: ref,
            event: 'followup_reviewed',
            recipientIds: [assignedTo],
            title: 'Task reviewed',
            body: 'Your report has been reviewed by the doctor',
            data: {
              'entityType': 'followup_task',
              'entityId': taskId,
            },
          );
        }
      } catch (_) {
        // Best-effort.
      }
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
        .select('''
          id,
          patient_id,
          dr_visit_id,
          assigned_to,
          created_by,
          due_date,
          title,
          notes,
          priority,
          target_ext_doctor_name,
          target_ext_doctor_hospital,
          target_ext_doctor_specialization,
          target_ext_doctor_phone,
          visit_instructions,
          scheduled_visit_date,
          is_external_doctor,
          ext_doctor_name,
          ext_doctor_specialization,
          ext_doctor_hospital,
          ext_doctor_phone,
          completion_notes,
          reviewed_by,
          reviewed_at,
          doctor_review_notes,
          status,
          completed_at,
          created_at,
          patients(full_name)
        ''')
        .eq('created_by', user.id)
        .order('created_at', ascending: false)
        .order('due_date', ascending: true));

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
        .select('''
          id,
          patient_id,
          dr_visit_id,
          assigned_to,
          created_by,
          due_date,
          title,
          notes,
          priority,
          target_ext_doctor_name,
          target_ext_doctor_hospital,
          target_ext_doctor_specialization,
          target_ext_doctor_phone,
          visit_instructions,
          scheduled_visit_date,
          is_external_doctor,
          ext_doctor_name,
          ext_doctor_specialization,
          ext_doctor_hospital,
          ext_doctor_phone,
          completion_notes,
          reviewed_by,
          reviewed_at,
          doctor_review_notes,
          status,
          completed_at,
          created_at,
          patients(full_name)
        ''')
        .eq('id', id)
        .maybeSingle());
    if (response == null) return null;
    return FollowupTask.fromJson(Map<String, dynamic>.from(response));
  } catch (e) {
    throw Exception(AppError.getMessage(e));
  }
});
