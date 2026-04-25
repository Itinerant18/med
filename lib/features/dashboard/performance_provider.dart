import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/supabase_client.dart';

class AssistantKpi {
  const AssistantKpi({
    required this.id,
    required this.fullName,
    required this.specialization,
    required this.patientsRegistered,
    required this.visitsCreated,
    required this.followupsTotal,
    required this.followupsCompleted,
    required this.followupsOverdue,
    required this.outsideVisitsTotal,
  });

  final String id;
  final String fullName;
  final String specialization;
  final int patientsRegistered;
  final int visitsCreated;
  final int followupsTotal;
  final int followupsCompleted;
  final int followupsOverdue;

  /// External-doctor visits the assistant accompanied a patient on. Counted
  /// separately from `followupsCompleted` because some completed follow-ups
  /// don't involve an external visit at all.
  final int outsideVisitsTotal;

  double get completionRate =>
      followupsTotal == 0 ? 0 : followupsCompleted / followupsTotal * 100;

  factory AssistantKpi.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) => (v as num?)?.toInt() ?? 0;
    return AssistantKpi(
      id: json['assistant_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Unknown',
      specialization: json['specialization']?.toString() ?? '',
      patientsRegistered: parseInt(json['patients_registered']),
      visitsCreated: parseInt(json['visits_created']),
      followupsTotal: parseInt(json['followups_total']),
      followupsCompleted: parseInt(json['followups_completed']),
      followupsOverdue: parseInt(json['followups_overdue']),
      outsideVisitsTotal: parseInt(json['outside_visits_total']),
    );
  }
}

final assistantPerformanceProvider =
    FutureProvider.autoDispose<List<AssistantKpi>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final response = await supabase.from('assistant_performance').select();
  return (response as List)
      .map((json) => AssistantKpi.fromJson(Map<String, dynamic>.from(json)))
      .toList();
});
