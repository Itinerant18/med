// lib/features/dashboard/dashboard_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/models/user_role.dart';

class DashboardState {
  final List<Map<String, dynamic>> todayVisits;
  final List<Map<String, dynamic>> highPriorityPatients;
  final int appointmentsCount;
  final int pendingLabsCount;
  final int upcomingOTCount;
  final bool isLive;

  const DashboardState({
    required this.todayVisits,
    required this.highPriorityPatients,
    this.appointmentsCount = 0,
    this.pendingLabsCount = 0,
    this.upcomingOTCount = 0,
    this.isLive = false,
  });
}

class DashboardNotifier
    extends AutoDisposeAsyncNotifier<DashboardState> {
  Timer? _timer;

  @override
  Future<DashboardState> build() async {
    ref.onDispose(() => _timer?.cancel());
    _timer = Timer.periodic(
      const Duration(seconds: 30), (_) => refresh());
    return _fetch();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<DashboardState> _fetch() async {
    final supabase = ref.read(supabaseClientProvider);
    final now = DateTime.now();
    final start =
        DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(
            now.year, now.month, now.day, 23, 59, 59)
        .toIso8601String();

    final userState = ref.read(authNotifierProvider).value;
    final isAssistant = userState?.role == UserRole.assistant;

    var visitsQuery = supabase
        .from('visits')
        .select('*, patients!inner(full_name, is_high_priority, created_by_id)')
        .gte('visit_date', start)
        .lte('visit_date', end);

    if (isAssistant) {
      visitsQuery = visitsQuery.eq('patients.created_by_id', userState!.session.user.id);
    }

    final visitsRaw = await visitsQuery.order('visit_date', ascending: false);

    final visits =
        List<Map<String, dynamic>>.from(visitsRaw);

    var priorityQuery = supabase
        .from('patients')
        .select(
            'id, full_name, service_status, '
            'last_updated_by, last_updated_at, is_high_priority, created_by_id')
        .eq('is_high_priority', true);

    if (isAssistant) {
      priorityQuery = priorityQuery.eq('created_by_id', userState!.session.user.id);
    }

    final priorityRaw = await priorityQuery
        .order('last_updated_at', ascending: false)
        .limit(10);

    final priority =
        List<Map<String, dynamic>>.from(priorityRaw);

    final pendingLabs = visits
        .where((v) => v['tests_performed'] == false)
        .length;
    final upcomingOT =
        visits.where((v) => v['ot_required'] == true).length;

    return DashboardState(
      todayVisits: visits,
      highPriorityPatients: priority,
      appointmentsCount: visits.length,
      pendingLabsCount: pendingLabs,
      upcomingOTCount: upcomingOT,
      isLive: true,
    );
  }
}

final dashboardProvider = AsyncNotifierProvider
    .autoDispose<DashboardNotifier, DashboardState>(
  DashboardNotifier.new,
);
