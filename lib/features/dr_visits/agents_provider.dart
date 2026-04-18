import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/models/doctor_model.dart';

final agentsProvider = FutureProvider<List<DoctorModel>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final response = await supabase
      .from('doctors')
      .select()
      .eq('role', 'assistant')
      .eq('approval_status', 'approved');

  return (response as List).map((json) => DoctorModel.fromJson(json)).toList();
});
