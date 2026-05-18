// lib/features/dashboard/dashboard_provider.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/core/realtime_service.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/features/followups/followup_provider.dart';
import 'package:mediflow/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _disposed = false;
  RealtimeChannel? _invalidateChannel;
  Timer? _realtimeConnectCheckTimer;
  Timer? _pollingTimer;
  SubscriptionStatus _channelStatus = SubscriptionStatus.disconnected;

  void _cancelInvalidateChannel() {
    _realtimeConnectCheckTimer?.cancel();
    _realtimeConnectCheckTimer = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;

    try {
      _invalidateChannel?.unsubscribe();
    } catch (_) {}
    _invalidateChannel = null;

    _channelStatus = SubscriptionStatus.disconnected;
  }

  void _startFallbackPolling() {
    if (_disposed || _pollingTimer != null) return;
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_disposed || !state.hasValue) return;
      refresh();
    });
  }

  void _attachInvalidationChannel(String userId, String todayStart) {
    _cancelInvalidateChannel();

    final supabase = Supabase.instance.client;
    final channel = supabase.channel('dashboard:invalidate:$userId');

    _channelStatus = SubscriptionStatus.connecting;
    _invalidateChannel = channel;

    // Supabase Realtime row filters must be enabled in the dashboard for this
    // server-side filter to be enforced.
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'visits',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.gte,
        column: 'visit_date',
        value: todayStart,
      ),
      callback: (_) {
        if (_disposed) return;
        refresh();
      },
    );

    channel.subscribe((status, error) {
      if (_disposed) return;

      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          _channelStatus = SubscriptionStatus.connected;
          _realtimeConnectCheckTimer?.cancel();
          _realtimeConnectCheckTimer = null;
          _pollingTimer?.cancel();
          _pollingTimer = null;
          break;
        case RealtimeSubscribeStatus.channelError:
        case RealtimeSubscribeStatus.timedOut:
          _channelStatus = SubscriptionStatus.error;
          debugPrint('Dashboard invalidate channel failed: $error');
          break;
        case RealtimeSubscribeStatus.closed:
          _channelStatus = SubscriptionStatus.disconnected;
          break;
      }
    });

    _realtimeConnectCheckTimer =
        Timer(const Duration(seconds: 5), () {
      if (_disposed) return;
      if (_channelStatus != SubscriptionStatus.connected) {
        _startFallbackPolling();
      }
    });
  }

  @override
  Future<DashboardState> build() async {
    _disposed = false;
    final cacheLink = ref.keepAlive();
    ref.listen<AsyncValue<AuthUserState?>>(authNotifierProvider, (prev, next) {
      if (_disposed) return;
      if (next.valueOrNull == null) {
        cacheLink.close();
        ref.invalidateSelf();
      }
    });

    ref.onDispose(() {
      _cancelInvalidateChannel();
      _disposed = true;
      cacheLink.close();
    });

    final initialState = await _fetch();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null && userId.isNotEmpty) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
      _attachInvalidationChannel(userId, todayStart);
    }
    return initialState;
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
    final userState = ref.read(authNotifierProvider).valueOrNull;
    final isAgent = userState?.role == UserRole.assistant;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay =
        DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    try {
      var visitsBuilder = supabase
          .from('visits')
          .select(
              'id, patient_id, patient_name, visit_date, visit_type, tests_performed, ot_required, patient_flow_status, last_updated_by, patients!inner(full_name, is_high_priority)')
          .gte('visit_date', startOfDay)
          .lte('visit_date', endOfDay);

      if (isAgent && userState != null) {
        visitsBuilder =
            visitsBuilder.eq('patients.created_by_id', userState.session.user.id);
      }

      final visitsFuture = supabase.retry(() => visitsBuilder
          .order('visit_date', ascending: false)
          .then((raw) => List<Map<String, dynamic>>.from(raw)));

      var priorityBuilder = supabase
          .from('patients')
          .select('id, full_name, service_status, last_updated_by, last_updated_at')
          .eq('is_high_priority', true);

      if (isAgent && userState != null) {
        priorityBuilder =
            priorityBuilder.eq('created_by_id', userState.session.user.id);
      }

      final priorityFuture = supabase.retry(() => priorityBuilder
          .order('last_updated_at', ascending: false)
          .limit(10)
          .then((raw) => List<Map<String, dynamic>>.from(raw)));

      final assignedVisitsFuture = (!isAgent || userState == null)
          ? Future.value(<Map<String, dynamic>>[])
          : supabase.retry(() => supabase
              .from('dr_visits')
              .select(
                  'id, visit_date, followup_status, patients:patients!dr_visits_patient_id_fkey(full_name)')
              .eq('assigned_agent_id', userState.session.user.id)
              .gte('visit_date', startOfDay)
              .lte('visit_date', endOfDay)
              .order('visit_date', ascending: false)
              .then((raw) => List<Map<String, dynamic>>.from(raw)));

      final followupTasksFuture = (!isAgent || userState == null)
          ? Future.value(<FollowupTask>[])
          : (() {
              final todayStr = DateTime(now.year, now.month, now.day)
                  .toIso8601String()
                  .split('T')[0];
              // Overdue marking is handled by FollowupTasksNotifier when the
              // Follow-ups tab opens; the dashboard just reads today's tasks.
              return supabase.retry(() => supabase
                  .from('followup_tasks')
                  .select('''
                    id,
                    patient_id,
                    dr_visit_id,
                    assigned_to,
                    created_by,
                    due_date,
                    title,
                    notes,
                    priority,
                    target_ext_doctor_name,
                    target_ext_doctor_hospital,
                    target_ext_doctor_specialization,
                    target_ext_doctor_phone,
                    visit_instructions,
                    scheduled_visit_date,
                    is_external_doctor,
                    ext_doctor_name,
                    ext_doctor_specialization,
                    ext_doctor_hospital,
                    ext_doctor_phone,
                    completion_notes,
                    reviewed_by,
                    reviewed_at,
                    doctor_review_notes,
                    status,
                    completed_at,
                    created_at,
                    patients(full_name)
                  ''')
                  .eq('assigned_to', userState.session.user.id)
                  .or('due_date.eq.$todayStr,status.eq.overdue')
                  .neq('status', 'completed')
                  .order('created_at', ascending: false)
                  .then((raw) => (raw as List)
                      .map((json) => FollowupTask.fromJson(
                          Map<String, dynamic>.from(json as Map)))
                      .toList()));
            })();

      final results = await Future.wait([
        visitsFuture,
        priorityFuture,
        assignedVisitsFuture,
        followupTasksFuture,
      ]);
      final visits = results[0] as List<Map<String, dynamic>>;
      final priority = results[1] as List<Map<String, dynamic>>;
      final assignedVisits = results[2] as List<Map<String, dynamic>>;
      final followupTasks = results[3] as List<FollowupTask>;

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
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }
}

final dashboardProvider =
    AsyncNotifierProvider.autoDispose<DashboardNotifier, DashboardState>(
  DashboardNotifier.new,
);
