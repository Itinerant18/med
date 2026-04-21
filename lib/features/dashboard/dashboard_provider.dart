// lib/features/dashboard/dashboard_provider.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/features/followups/followup_provider.dart';
import 'package:mediflow/models/user_role.dart';

class DashboardStats {
  final int todayVisitsCount;
  final int pendingLabsCount;
  final int upcomingOTCount;
  final int highPriorityCount;

  const DashboardStats({
    this.todayVisitsCount = 0,
    this.pendingLabsCount = 0,
    this.upcomingOTCount = 0,
    this.highPriorityCount = 0,
  });
}

class DashboardState {
  final List<Map<String, dynamic>> todayVisits;
  final List<Map<String, dynamic>> highPriorityPatients;
  final List<Map<String, dynamic>> assignedVisits;
  final List<FollowupTask> followupTasks;
  final DashboardStats stats;
  final bool isLive;
  final DateTime? lastRefreshed;

  const DashboardState({
    required this.todayVisits,
    required this.highPriorityPatients,
    this.assignedVisits = const [],
    this.followupTasks = const [],
    this.stats = const DashboardStats(),
    this.isLive = false,
    this.lastRefreshed,
  });

  DashboardState copyWith({
    List<Map<String, dynamic>>? todayVisits,
    List<Map<String, dynamic>>? highPriorityPatients,
    List<Map<String, dynamic>>? assignedVisits,
    List<FollowupTask>? followupTasks,
    DashboardStats? stats,
    bool? isLive,
    DateTime? lastRefreshed,
  }) {
    return DashboardState(
      todayVisits: todayVisits ?? this.todayVisits,
      highPriorityPatients: highPriorityPatients ?? this.highPriorityPatients,
      assignedVisits: assignedVisits ?? this.assignedVisits,
      followupTasks: followupTasks ?? this.followupTasks,
      stats: stats ?? this.stats,
      isLive: isLive ?? this.isLive,
      lastRefreshed: lastRefreshed ?? this.lastRefreshed,
    );
  }
}

class DashboardNotifier extends AutoDisposeAsyncNotifier<DashboardState> {
  Timer? _timer;
  bool _disposed = false;

  @override
  Future<DashboardState> build() async {
    _disposed = false;

    // Cancel any timer left over from a previous build (e.g. hot reload)
    // before scheduling a new one.
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_disposed) return;
      if (state.hasValue) refresh();
    });

    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
      _timer = null;
    });

    return _fetch();
  }

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    try {
      final next = await _fetch();
      if (!_disposed) {
        state = AsyncData(next);
      }
    } catch (e, st) {
      if (!_disposed && previous != null) {
        state = AsyncData(previous);
      } else if (!_disposed) {
        state = AsyncError(e, st);
      }
    }
  }

  Future<DashboardState> _fetch() async {
    final supabase = ref.read(supabaseClientProvider);
    final userState = ref.read(authNotifierProvider).value;
    final isAgent = userState?.role == UserRole.assistant;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay =
        DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    var visitsQuery = supabase
        .from('visits')
        .select('*, patients!inner(full_name, is_high_priority, created_by_id)')
        .gte('visit_date', startOfDay)
        .lte('visit_date', endOfDay);

    if (isAgent && userState != null) {
      visitsQuery =
          visitsQuery.eq('patients.created_by_id', userState.session.user.id);
    }

    final visitsRaw = await visitsQuery.order('visit_date', ascending: false);
    final visits = List<Map<String, dynamic>>.from(visitsRaw);

    var priorityQuery = supabase
        .from('patients')
        .select(
            'id, full_name, service_status, last_updated_by, last_updated_at, is_high_priority, created_by_id')
        .eq('is_high_priority', true);

    if (isAgent && userState != null) {
      priorityQuery =
          priorityQuery.eq('created_by_id', userState.session.user.id);
    }

    final priorityRaw = await priorityQuery
        .order('last_updated_at', ascending: false)
        .limit(10);
    final priority = List<Map<String, dynamic>>.from(priorityRaw);

    List<Map<String, dynamic>> assignedVisits = [];
    if (isAgent && userState != null) {
      final assignedRaw = await supabase
          .from('dr_visits')
          .select('*, patients(full_name)')
          .eq('assigned_agent_id', userState.session.user.id)
          .gte('visit_date', startOfDay)
          .lte('visit_date', endOfDay)
          .order('visit_date', ascending: false);
      assignedVisits = List<Map<String, dynamic>>.from(assignedRaw);
    }

    List<FollowupTask> followupTasks = [];
    if (isAgent && userState != null) {
      final todayStr = DateTime(now.year, now.month, now.day)
          .toIso8601String()
          .split('T')[0];

      // Overdue marking is handled by FollowupTasksNotifier when the
      // Follow-ups tab opens; the dashboard just reads today's tasks.
      final followupRaw = await supabase
          .from('followup_tasks')
          .select('*, patients(full_name)')
          .eq('assigned_to', userState.session.user.id)
          .eq('due_date', todayStr)
          .neq('status', 'completed')
          .order('created_at', ascending: false);
      followupTasks = (followupRaw as List)
          .map((json) =>
              FollowupTask.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
    }

    final pendingLabs =
        visits.where((v) => v['tests_performed'] == false).length;
    final upcomingOT = visits.where((v) => v['ot_required'] == true).length;

    return DashboardState(
      todayVisits: visits,
      highPriorityPatients: priority,
      assignedVisits: assignedVisits,
      followupTasks: followupTasks,
      stats: DashboardStats(
        todayVisitsCount: visits.length,
        pendingLabsCount: pendingLabs,
        upcomingOTCount: upcomingOT,
        highPriorityCount: priority.length,
      ),
      isLive: true,
      lastRefreshed: DateTime.now(),
    );
  }
}

final dashboardProvider =
    AsyncNotifierProvider.autoDispose<DashboardNotifier, DashboardState>(
  DashboardNotifier.new,
);
