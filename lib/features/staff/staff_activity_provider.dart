// lib/features/staff/staff_activity_provider.dart
//
// Aggregates per-staff activity for a single date so the Network Directory
// can show "today's activity" footers on doctor and agent cards plus a
// drill-in sheet with the underlying items.
//
// Performance: one batched query per metric, regardless of team size.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/supabase_client.dart';

/// Currently-selected date for activity views in the Directory tab.
/// Defaults to today; date is "day-normalized" (time stripped) so the
/// activityProvider cache key is stable.
final selectedActivityDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

@immutable
class StaffActivity {
  const StaffActivity({
    required this.userId,
    this.drVisits = const [],
    this.outsideVisits = const [],
    this.followupsAssigned = const [],
    this.followupsCompleted = const [],
  });

  final String userId;
  // For doctors:
  final List<Map<String, dynamic>> drVisits;
  final List<Map<String, dynamic>> followupsAssigned;
  // For agents:
  final List<Map<String, dynamic>> outsideVisits;
  final List<Map<String, dynamic>> followupsCompleted;

  int get visitCount => drVisits.length + outsideVisits.length;
  int get followupCount => followupsAssigned.length + followupsCompleted.length;
  int get totalCount => visitCount + followupCount;
  bool get isEmpty => totalCount == 0;
}

/// Returns activity grouped by user id, for the given date.
final staffActivityProvider = FutureProvider.autoDispose
    .family<Map<String, StaffActivity>, DateTime>((ref, date) async {
  final supabase = ref.read(supabaseClientProvider);

  // Day window: [startOfDay, startOfNextDay).
  final dayStart = DateTime(date.year, date.month, date.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final isoDate = DateFormat('yyyy-MM-dd').format(dayStart);
  final isoStart = dayStart.toUtc().toIso8601String();
  final isoEnd = dayEnd.toUtc().toIso8601String();

  // Run all four queries in parallel.
  final results = await Future.wait<List<dynamic>>([
    // 1. dr_visits today (timestamptz) — grouped by doctor_id
    supabase
        .from('dr_visits')
        .select(
            'id, doctor_id, patient_id, visit_date, status, followup_status, '
            'patients(full_name)')
        .gte('visit_date', isoStart)
        .lt('visit_date', isoEnd)
        .order('visit_date', ascending: false)
        .then((v) => v as List<dynamic>)
        .catchError((e, st) {
      debugPrint('[staffActivity] dr_visits failed: $e');
      return <dynamic>[];
    }),

    // 2. agent_outside_visits today (DATE column) — grouped by agent_id
    supabase
        .from('agent_outside_visits')
        .select(
            'id, agent_id, patient_id, visit_date, ext_doctor_name, '
            'ext_doctor_hospital, status, patients(full_name)')
        .eq('visit_date', isoDate)
        .order('created_at', ascending: false)
        .then((v) => v as List<dynamic>)
        .catchError((e, st) {
      debugPrint('[staffActivity] agent_outside_visits failed: $e');
      return <dynamic>[];
    }),

    // 3. followup_tasks created today — grouped by created_by (doctor)
    supabase
        .from('followup_tasks')
        .select(
            'id, created_by, assigned_to, patient_id, due_date, status, '
            'created_at, completed_at, patients(full_name)')
        .gte('created_at', isoStart)
        .lt('created_at', isoEnd)
        .order('created_at', ascending: false)
        .then((v) => v as List<dynamic>)
        .catchError((e, st) {
      debugPrint('[staffActivity] followup_tasks (created) failed: $e');
      return <dynamic>[];
    }),

    // 4. followup_tasks completed today — grouped by assigned_to (agent)
    supabase
        .from('followup_tasks')
        .select(
            'id, created_by, assigned_to, patient_id, due_date, status, '
            'created_at, completed_at, patients(full_name)')
        .eq('status', 'completed')
        .gte('completed_at', isoStart)
        .lt('completed_at', isoEnd)
        .order('completed_at', ascending: false)
        .then((v) => v as List<dynamic>)
        .catchError((e, st) {
      debugPrint('[staffActivity] followup_tasks (completed) failed: $e');
      return <dynamic>[];
    }),
  ]);

  final drVisitsByDoctor = <String, List<Map<String, dynamic>>>{};
  for (final raw in results[0]) {
    final row = Map<String, dynamic>.from(raw as Map);
    final id = row['doctor_id']?.toString();
    if (id == null || id.isEmpty) continue;
    drVisitsByDoctor.putIfAbsent(id, () => []).add(row);
  }

  final outsideByAgent = <String, List<Map<String, dynamic>>>{};
  for (final raw in results[1]) {
    final row = Map<String, dynamic>.from(raw as Map);
    final id = row['agent_id']?.toString();
    if (id == null || id.isEmpty) continue;
    outsideByAgent.putIfAbsent(id, () => []).add(row);
  }

  final followupsAssignedByDoctor = <String, List<Map<String, dynamic>>>{};
  for (final raw in results[2]) {
    final row = Map<String, dynamic>.from(raw as Map);
    final id = row['created_by']?.toString();
    if (id == null || id.isEmpty) continue;
    followupsAssignedByDoctor.putIfAbsent(id, () => []).add(row);
  }

  final followupsCompletedByAgent = <String, List<Map<String, dynamic>>>{};
  for (final raw in results[3]) {
    final row = Map<String, dynamic>.from(raw as Map);
    final id = row['assigned_to']?.toString();
    if (id == null || id.isEmpty) continue;
    followupsCompletedByAgent.putIfAbsent(id, () => []).add(row);
  }

  // Merge into a single map keyed by userId.
  final allUserIds = <String>{
    ...drVisitsByDoctor.keys,
    ...outsideByAgent.keys,
    ...followupsAssignedByDoctor.keys,
    ...followupsCompletedByAgent.keys,
  };

  return {
    for (final id in allUserIds)
      id: StaffActivity(
        userId: id,
        drVisits: drVisitsByDoctor[id] ?? const [],
        outsideVisits: outsideByAgent[id] ?? const [],
        followupsAssigned: followupsAssignedByDoctor[id] ?? const [],
        followupsCompleted: followupsCompletedByAgent[id] ?? const [],
      ),
  };
});
