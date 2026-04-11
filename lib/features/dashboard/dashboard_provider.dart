import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/supabase_client.dart';

class DashboardState {
  final List<Map<String, dynamic>> todayVisits;
  final int appointmentsCount;
  final int pendingLabsCount;
  final int upcomingOTCount;
  final bool isLive;

  DashboardState({
    required this.todayVisits,
    required this.appointmentsCount,
    required this.pendingLabsCount,
    required this.upcomingOTCount,
    this.isLive = false,
  });
}

final dashboardProvider = StreamProvider.autoDispose<DashboardState>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  
  // Realtime subscription to the visits table
  final stream = supabase
      .from('visits')
      .stream(primaryKey: ['id'])
      .order('visit_date', ascending: false);

  return stream.asyncMap((data) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    
    // Fetch today's visits with patient and doctor details
    final todayVisits = await supabase
        .from('visits')
        .select('*, patients(*), doctors(*)')
        .gte('visit_date', todayStart)
        .order('visit_date', ascending: false);

    // Calculate counts for summary cards
    final pendingLabs = todayVisits.where((v) => v['test_status'] == 'pending').length;
    final upcomingOT = todayVisits.where((v) => v['ot_required'] == true).length;

    return DashboardState(
      todayVisits: todayVisits,
      appointmentsCount: todayVisits.length,
      pendingLabsCount: pendingLabs,
      upcomingOTCount: upcomingOT,
      isLive: true, // If we are here, the stream is active
    );
  });
});
