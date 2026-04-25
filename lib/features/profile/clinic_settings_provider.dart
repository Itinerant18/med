import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/supabase_client.dart';

class ClinicSettingsNotifier extends AsyncNotifier<Map<String, dynamic>> {
  @override
  FutureOr<Map<String, dynamic>> build() async {
    final supabase = ref.watch(supabaseClientProvider);
    final response = await supabase
        .from('clinic_settings')
        .select()
        .limit(1)
        .maybeSingle();
    
    return response ?? {};
  }

  Future<void> updateSettings(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final supabase = ref.read(supabaseClientProvider);
      final current = state.valueOrNull;

      if (current != null && current.containsKey('id')) {
        await supabase
            .from('clinic_settings')
            .update({...data, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', current['id']);
      } else {
        await supabase
            .from('clinic_settings')
            .insert({...data, 'updated_at': DateTime.now().toIso8601String()});
      }

      final updated = await supabase
          .from('clinic_settings')
          .select()
          .limit(1)
          .maybeSingle();
      return updated == null ? <String, dynamic>{} : Map<String, dynamic>.from(updated);
    });
  }
}

final clinicSettingsProvider = AsyncNotifierProvider<ClinicSettingsNotifier, Map<String, dynamic>>(() {
  return ClinicSettingsNotifier();
});
