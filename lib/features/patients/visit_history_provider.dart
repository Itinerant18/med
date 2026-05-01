// lib/features/patients/visit_history_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/supabase_client.dart';

class VisitHistoryQuery {
  const VisitHistoryQuery({
    required this.patientId,
    this.limit = 50,
    this.offset = 0,
  });

  final String patientId;
  final int limit;
  final int offset;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VisitHistoryQuery &&
        other.patientId == patientId &&
        other.limit == limit &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(patientId, limit, offset);
}

final visitHistoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, VisitHistoryQuery>(
        (ref, query) async {
  final supabase = ref.read(supabaseClientProvider);
  const projection = 'id, visit_date, visit_type, chief_complaint, '
      'chief_complaint_custom, tests_performed, ot_required, '
      'patient_flow_status, final_diagnosis, prescriptions, last_updated_by, '
      'bp_systolic, bp_diastolic, pulse, temperature, spo2, respiratory_rate';
  final response = await supabase
      .from('visits')
      .select(projection)
      .eq('patient_id', query.patientId)
      .order('visit_date', ascending: false)
      .range(query.offset, query.offset + query.limit - 1);
  return List<Map<String, dynamic>>.from(response);
});
