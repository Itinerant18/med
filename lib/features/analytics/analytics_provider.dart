import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/models/user_role.dart';

/// Daily visit count bucket used for time-series analytics.
class DailyVisitCount {
  /// Creates a daily visit count bucket.
  const DailyVisitCount({
    required this.date,
    required this.count,
  });

  /// Day represented by this bucket.
  final DateTime date;

  /// Number of visits recorded on [date].
  final int count;
}

/// Aggregated analytics data for dashboard summary cards and charts.
class AnalyticsSummary {
  /// Creates an analytics summary snapshot.
  const AnalyticsSummary({
    required this.totalPatients,
    required this.totalVisits,
    required this.totalDrVisits,
    required this.activeStaff,
    required this.pendingApprovals,
    required this.highPriorityPatients,
    required this.todayVisits,
    required this.avgVisitsPerDay,
    required this.visitsByType,
    required this.patientsByScheme,
    required this.followupCompletion,
    required this.last30DaysVisits,
  });

  /// Empty analytics state used for agents or fallback scenarios.
  factory AnalyticsSummary.empty() {
    return const AnalyticsSummary(
      totalPatients: 0,
      totalVisits: 0,
      totalDrVisits: 0,
      activeStaff: 0,
      pendingApprovals: 0,
      highPriorityPatients: 0,
      todayVisits: 0,
      avgVisitsPerDay: 0,
      visitsByType: {
        'OPD': 0,
        'IPD': 0,
        'Emergency': 0,
      },
      patientsByScheme: {
        'insurance': 0,
        'cash': 0,
        'sastho_sathi': 0,
        'other': 0,
      },
      followupCompletion: 0,
      last30DaysVisits: [],
    );
  }

  /// Total patients visible to the current user.
  final int totalPatients;

  /// Total visits visible to the current user.
  final int totalVisits;

  /// Total doctor visits visible to the current user.
  final int totalDrVisits;

  /// Count of approved staff members.
  final int activeStaff;

  /// Count of pending staff approvals.
  final int pendingApprovals;

  /// Count of high-priority patients.
  final int highPriorityPatients;

  /// Count of visits recorded today.
  final int todayVisits;

  /// Average visits per active day in the last 30 days.
  final double avgVisitsPerDay;

  /// Visit counts grouped by visit type.
  final Map<String, int> visitsByType;

  /// Patient counts grouped by health scheme.
  final Map<String, int> patientsByScheme;

  /// Ratio of completed follow-up tasks to total follow-up tasks.
  final double followupCompletion;

  /// Visit counts grouped by day for the last 30 days.
  final List<DailyVisitCount> last30DaysVisits;
}

/// Per-staff performance snapshot for head doctor analytics views.
class StaffPerformance {
  /// Creates a staff performance row.
  const StaffPerformance({
    required this.doctorId,
    required this.doctorName,
    required this.role,
    required this.visitsCount,
    required this.patientsCount,
    required this.drVisitsCount,
    required this.followupsCompleted,
  });

  /// Staff user's doctor/profile identifier.
  final String doctorId;

  /// Staff display name.
  final String doctorName;

  /// Staff role string from the database.
  final String role;

  /// Count of visits owned by this staff member.
  final int visitsCount;

  /// Count of patients created by this staff member.
  final int patientsCount;

  /// Count of doctor visits created/owned by this staff member.
  final int drVisitsCount;

  /// Count of completed follow-ups assigned to this staff member.
  final int followupsCompleted;
}

final _last30DaysStartProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
});

/// Provides dashboard analytics for the signed-in user.
final analyticsSummaryProvider =
    FutureProvider.autoDispose<AnalyticsSummary>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final userState = ref.read(authNotifierProvider).value;

  if (userState == null || userState.role == UserRole.assistant) {
    return AnalyticsSummary.empty();
  }

  final userId = userState.session.user.id;
  final isHeadDoctor = userState.role == UserRole.headDoctor;
  final last30DaysStart = ref.read(_last30DaysStartProvider);
  final last30DaysStartIso = last30DaysStart.toIso8601String();

  final patientsQuery = isHeadDoctor
      ? supabase.from('patients').select(
          'id, is_high_priority, health_scheme, created_by_id, created_at, last_updated_at')
      : supabase
          .from('patients')
          .select(
              'id, is_high_priority, health_scheme, created_by_id, created_at, last_updated_at')
          .eq('created_by_id', userId);

  final visitsQuery = isHeadDoctor
      ? supabase.from('visits').select(
          'id, doctor_id, visit_type, tests_performed, ot_required, patient_flow_status, visit_date, created_by_id')
      : supabase
          .from('visits')
          .select(
              'id, doctor_id, visit_type, tests_performed, ot_required, patient_flow_status, visit_date, created_by_id')
          .eq('doctor_id', userId);

  final drVisitsQuery = isHeadDoctor
      ? supabase.from('dr_visits').select(
          'id, doctor_id, assigned_agent_id, followup_status, status, visit_date')
      : supabase
          .from('dr_visits')
          .select(
              'id, doctor_id, assigned_agent_id, followup_status, status, visit_date')
          .eq('doctor_id', userId);

  final followupsQuery = isHeadDoctor
      ? supabase
          .from('followup_tasks')
          .select('id, assigned_to, status, due_date, created_at')
      : supabase
          .from('followup_tasks')
          .select('id, assigned_to, status, due_date, created_at')
          .eq('assigned_to', userId);

  final doctorsQuery = isHeadDoctor
      ? supabase
          .from('doctors')
          .select('id, full_name, role, approval_status, created_at')
      : Future.value(<dynamic>[]);

  final recentVisitsQuery = isHeadDoctor
      ? supabase
          .from('visits')
          .select('visit_date')
          .gte('visit_date', last30DaysStartIso)
      : supabase
          .from('visits')
          .select('visit_date')
          .eq('doctor_id', userId)
          .gte('visit_date', last30DaysStartIso);

  final results = await Future.wait<dynamic>([
    patientsQuery,
    visitsQuery,
    drVisitsQuery,
    followupsQuery,
    doctorsQuery,
    recentVisitsQuery,
  ]);

  final patients = List<Map<String, dynamic>>.from(results[0] as List);
  final visits = List<Map<String, dynamic>>.from(results[1] as List);
  final drVisits = List<Map<String, dynamic>>.from(results[2] as List);
  final followups = List<Map<String, dynamic>>.from(results[3] as List);
  final doctors = isHeadDoctor
      ? List<Map<String, dynamic>>.from(results[4] as List)
      : const <Map<String, dynamic>>[];
  final recentVisits = List<Map<String, dynamic>>.from(results[5] as List);

  final visitsByType = <String, int>{
    'OPD': 0,
    'IPD': 0,
    'Emergency': 0,
  };
  for (final visit in visits) {
    final type = (visit['visit_type'] ?? '').toString();
    if (visitsByType.containsKey(type)) {
      visitsByType[type] = visitsByType[type]! + 1;
    }
  }

  final patientsByScheme = <String, int>{
    'insurance': 0,
    'cash': 0,
    'sastho_sathi': 0,
    'other': 0,
  };
  for (final patient in patients) {
    final scheme = (patient['health_scheme'] ?? 'other').toString().toLowerCase();
    final normalizedScheme =
        patientsByScheme.containsKey(scheme) ? scheme : 'other';
    patientsByScheme[normalizedScheme] =
        patientsByScheme[normalizedScheme]! + 1;
  }

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = todayStart.add(const Duration(days: 1));
  final todayVisits = visits.where((visit) {
    final rawDate = visit['visit_date'];
    if (rawDate is! String) return false;
    final parsed = DateTime.tryParse(rawDate);
    return parsed != null &&
        !parsed.isBefore(todayStart) &&
        parsed.isBefore(todayEnd);
  }).length;

  final totalFollowups = followups.length;
  final completedFollowups = followups
      .where((task) => (task['status'] ?? '').toString().toLowerCase() == 'completed')
      .length;
  final followupCompletion =
      totalFollowups == 0 ? 0.0 : completedFollowups / totalFollowups;

  final groupedLast30Days = <DateTime, int>{};
  for (final visit in recentVisits) {
    final rawDate = visit['visit_date'];
    if (rawDate is! String) continue;
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) continue;
    final bucket = DateTime(parsed.year, parsed.month, parsed.day);
    groupedLast30Days[bucket] = (groupedLast30Days[bucket] ?? 0) + 1;
  }

  final last30DaysVisits = List<DailyVisitCount>.generate(30, (index) {
    final date = last30DaysStart.add(Duration(days: index));
    return DailyVisitCount(
      date: date,
      count: groupedLast30Days[date] ?? 0,
    );
  });

  final activeDays = last30DaysVisits.where((entry) => entry.count > 0).length;
  final avgVisitsPerDay = activeDays == 0
      ? 0.0
      : recentVisits.length / activeDays;

  final activeStaff = isHeadDoctor
      ? doctors
          .where((doctor) =>
              (doctor['approval_status'] ?? '').toString().toLowerCase() ==
              'approved')
          .length
      : 0;

  final pendingApprovals = isHeadDoctor
      ? doctors
          .where((doctor) =>
              (doctor['approval_status'] ?? '').toString().toLowerCase() ==
              'pending')
          .length
      : 0;

  final highPriorityPatients = patients
      .where((patient) => (patient['is_high_priority'] ?? false) == true)
      .length;

  return AnalyticsSummary(
    totalPatients: patients.length,
    totalVisits: visits.length,
    totalDrVisits: drVisits.length,
    activeStaff: activeStaff,
    pendingApprovals: pendingApprovals,
    highPriorityPatients: highPriorityPatients,
    todayVisits: todayVisits,
    avgVisitsPerDay: avgVisitsPerDay,
    visitsByType: visitsByType,
    patientsByScheme: patientsByScheme,
    followupCompletion: followupCompletion,
    last30DaysVisits: last30DaysVisits,
  );
});

/// Provides staff-level performance analytics for head doctors.
final staffPerformanceProvider =
    FutureProvider.autoDispose<List<StaffPerformance>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final userState = ref.read(authNotifierProvider).value;

  if (userState == null || userState.role != UserRole.headDoctor) {
    return const <StaffPerformance>[];
  }

  final results = await Future.wait<dynamic>([
    supabase
        .from('doctors')
        .select('id, full_name, role, approval_status, created_at'),
    supabase.from('visits').select('id, doctor_id, created_by_id'),
    supabase.from('patients').select('id, created_by_id'),
    supabase.from('dr_visits').select('id, doctor_id'),
    supabase.from('followup_tasks').select('id, assigned_to, status'),
  ]);

  final doctors = List<Map<String, dynamic>>.from(results[0] as List)
      .where((doctor) =>
          (doctor['approval_status'] ?? '').toString().toLowerCase() == 'approved')
      .toList();
  final visits = List<Map<String, dynamic>>.from(results[1] as List);
  final patients = List<Map<String, dynamic>>.from(results[2] as List);
  final drVisits = List<Map<String, dynamic>>.from(results[3] as List);
  final followups = List<Map<String, dynamic>>.from(results[4] as List);

  final performance = doctors.map((doctor) {
    final doctorId = doctor['id'].toString();
    final visitsCount = visits
        .where((visit) => (visit['doctor_id'] ?? visit['created_by_id']).toString() == doctorId)
        .length;
    final patientsCount = patients
        .where((patient) => (patient['created_by_id'] ?? '').toString() == doctorId)
        .length;
    final drVisitsCount = drVisits
        .where((drVisit) => (drVisit['doctor_id'] ?? '').toString() == doctorId)
        .length;
    final followupsCompleted = followups
        .where((task) =>
            (task['assigned_to'] ?? '').toString() == doctorId &&
            (task['status'] ?? '').toString().toLowerCase() == 'completed')
        .length;

    return StaffPerformance(
      doctorId: doctorId,
      doctorName: (doctor['full_name'] ?? '').toString(),
      role: (doctor['role'] ?? '').toString(),
      visitsCount: visitsCount,
      patientsCount: patientsCount,
      drVisitsCount: drVisitsCount,
      followupsCompleted: followupsCompleted,
    );
  }).toList();

  performance.sort((a, b) => b.visitsCount.compareTo(a.visitsCount));
  return performance;
});
