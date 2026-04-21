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
  });

  final String id;
  final String fullName;
  final String specialization;
  final int patientsRegistered;
  final int visitsCreated;
  final int followupsTotal;
  final int followupsCompleted;
  final int followupsOverdue;

  double get completionRate =>
      followupsTotal == 0 ? 0 : followupsCompleted / followupsTotal * 100;

  factory AssistantKpi.fromJson(Map<String, dynamic> json) {
    return AssistantKpi(
      id: json['assistant_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Unknown',
      specialization: json['specialization']?.toString() ?? '',
      patientsRegistered: (json['patients_registered'] as num?)?.toInt() ?? 0,
      visitsCreated: (json['visits_created'] as num?)?.toInt() ?? 0,
      followupsTotal: (json['followups_total'] as num?)?.toInt() ?? 0,
      followupsCompleted: (json['followups_completed'] as num?)?.toInt() ?? 0,
      followupsOverdue: (json['followups_overdue'] as num?)?.toInt() ?? 0,
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
