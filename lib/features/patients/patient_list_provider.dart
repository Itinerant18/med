// lib/features/patients/patient_list_provider.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/models/patient_model.dart';
import 'package:mediflow/models/user_role.dart';


enum HealthSchemeFilter { all, insurance, cash, sasthoSathi, other }

enum PriorityFilter { all, highOnly }

enum DateRangeFilter { last7Days, last30Days, last3Months, allTime }

enum VisitTypeFilter { all, opd, ipd, emergency }

enum SortOption {
  nameAsc,
  nameDesc,
  mostRecentVisit,
  highPriorityFirst,
  newestRegistered
}

class SearchFilter {
  const SearchFilter({
    required this.query,
    required this.healthScheme,
    required this.priority,
    required this.dateRange,
    required this.visitType,
    required this.sortOption,
    this.limit = 100,
    this.offset = 0,
  });

  final String query;
  final HealthSchemeFilter healthScheme;
  final PriorityFilter priority;
  final DateRangeFilter dateRange;
  final VisitTypeFilter visitType;
  final SortOption sortOption;
  final int limit;
  final int offset;

  SearchFilter copyWith({
    String? query,
    HealthSchemeFilter? healthScheme,
    PriorityFilter? priority,
    DateRangeFilter? dateRange,
    VisitTypeFilter? visitType,
    SortOption? sortOption,
    int? limit,
    int? offset,
  }) {
    return SearchFilter(
      query: query ?? this.query,
      healthScheme: healthScheme ?? this.healthScheme,
      priority: priority ?? this.priority,
      dateRange: dateRange ?? this.dateRange,
      visitType: visitType ?? this.visitType,
      sortOption: sortOption ?? this.sortOption,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SearchFilter &&
        other.query == query &&
        other.healthScheme == healthScheme &&
        other.priority == priority &&
        other.dateRange == dateRange &&
        other.visitType == visitType &&
        other.sortOption == sortOption &&
        other.limit == limit &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(query, healthScheme, priority, dateRange,
      visitType, sortOption, limit, offset);
}

const _patientListSelect =
    'id, full_name, phone, email, symptoms, health_scheme, service_status, '
    'is_high_priority, last_updated_by, last_updated_at, created_by_id, '
    'created_at, area_affected, date_of_birth';

// Role-aware filtered provider that respects RBAC:
// Head doctors/doctors see everyone, agents see only patients they created.
final roleAwarePatientsProvider = FutureProvider.autoDispose
    .family<List<PatientModel>, SearchFilter>((ref, filter) async {
  final keepAliveLink = ref.keepAlive();
  final cacheTimer = Timer(const Duration(seconds: 30), keepAliveLink.close);
  ref.onDispose(cacheTimer.cancel);

  if (filter.query.isNotEmpty) {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  bool isDisposed = false;
  ref.onDispose(() {
    isDisposed = true;
  });
  if (isDisposed) return [];

  final supabase = ref.watch(supabaseClientProvider);
  final userState = ref.watch(authNotifierProvider).value;
  final role = ref.watch(currentRoleProvider);

  try {
    var query = supabase.from('patients').select(_patientListSelect);

    if (role == UserRole.assistant && userState != null) {
      query = query.eq('created_by_id', userState.session.user.id);
    }

    if (filter.query.trim().isNotEmpty) {
      final q = '%${filter.query.trim()}%';
      query = query.or(
          'full_name.ilike.$q,phone.ilike.$q,email.ilike.$q,symptoms.ilike.$q,area_affected.ilike.$q');
    }

    if (filter.healthScheme != HealthSchemeFilter.all) {
      final schemeStr = switch (filter.healthScheme) {
        HealthSchemeFilter.insurance => 'insurance',
        HealthSchemeFilter.cash => 'cash',
        HealthSchemeFilter.sasthoSathi => 'sastho_sathi',
        HealthSchemeFilter.other => 'other',
        _ => null,
      };
      if (schemeStr != null) {
        query = query.eq('health_scheme', schemeStr);
      }
    }

    if (filter.priority == PriorityFilter.highOnly) {
      query = query.eq('is_high_priority', true);
    }

    if (filter.dateRange != DateRangeFilter.allTime) {
      final now = DateTime.now();
      final cutoff = switch (filter.dateRange) {
        DateRangeFilter.last7Days => now.subtract(const Duration(days: 7)),
        DateRangeFilter.last30Days => now.subtract(const Duration(days: 30)),
        DateRangeFilter.last3Months => now.subtract(const Duration(days: 90)),
        _ => DateTime(1900),
      };
      query = query.gte('last_updated_at', cutoff.toIso8601String());
    }

    final transformQuery = switch (filter.sortOption) {
      SortOption.nameAsc => query.order('full_name', ascending: true),
      SortOption.nameDesc => query.order('full_name', ascending: false),
      SortOption.mostRecentVisit =>
        query.order('last_updated_at', ascending: false),
      SortOption.highPriorityFirst => query
          .order('is_high_priority', ascending: false)
          .order('full_name', ascending: true),
      SortOption.newestRegistered =>
        query.order('created_at', ascending: false),
    }.range(filter.offset, filter.offset + filter.limit - 1);

    final response = await supabase.retry(() => transformQuery);
    return (response as List)
        .map((row) => PatientModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  } catch (e) {
    if (isDisposed) return [];
    throw Exception(AppError.getMessage(e));
  }
});

// Helper provider for total count (respecting RBAC)
final patientTotalCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final userState = ref.watch(authNotifierProvider).value;
  final role = ref.watch(currentRoleProvider);

  try {
    var query = supabase.from('patients').select('id');

    if (role == UserRole.assistant && userState != null) {
      query = query.eq('created_by_id', userState.session.user.id);
    }

    final response = await supabase.retry(() => query);
    return (response as List).length;
  } catch (e) {
    return 0;
  }
});
