import os

path = 'lib/features/patients/patient_list_provider.dart'

content = r"""// lib/features/patients/patient_list_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    this.limit = 20,
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

// Role-aware filtered provider that respects RBAC:
// Head doctors/doctors see everyone, agents see only patients they created.
final roleAwarePatientsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, SearchFilter>((ref, filter) async {
  // 1. Add 300ms debounce for search queries to reduce Supabase load.
  if (filter.query.isNotEmpty) {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // Check if the request was cancelled during the debounce.
  final link = ref.keepAlive();
  bool isDisposed = false;
  ref.onDispose(() {
    isDisposed = true;
    // Don't keep alive indefinitely if it was disposed during fetch.
    link.close();
  });
  if (isDisposed) return [];

  final supabase = ref.watch(supabaseClientProvider);
  final userState = ref.watch(authNotifierProvider).value;
  final role = ref.watch(currentRoleProvider);

  try {
    var query = supabase.from('patients').select(
        'id, full_name, phone, email, symptoms, health_scheme, service_status, is_high_priority, last_updated_by, last_updated_at, created_by_id, created_at, area_affected, date_of_birth');

    // 2. Server-side Filtering (RBAC)
    // Agents only see patients they created.
    if (role == UserRole.assistant && userState != null) {
      query = query.eq('created_by_id', userState.session.user.id);
    }

    // 3. Server-side Search
    if (filter.query.trim().isNotEmpty) {
      final q = '%${filter.query.trim()}%';
      query = query.or(
          'full_name.ilike.$q,phone.ilike.$q,email.ilike.$q,symptoms.ilike.$q,area_affected.ilike.$q');
    }

    // 4. Server-side Category Filters
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

    // 5. Server-side Sorting
    PostgrestTransformBuilder<PostgrestList> transformQuery;
    switch (filter.sortOption) {
      case SortOption.nameAsc:
        transformQuery = query.order('full_name', ascending: true);
      case SortOption.nameDesc:
        transformQuery = query.order('full_name', ascending: false);
      case SortOption.mostRecentVisit:
        transformQuery = query.order('last_updated_at', ascending: false);
      case SortOption.highPriorityFirst:
        transformQuery = query
            .order('is_high_priority', ascending: false)
            .order('full_name', ascending: true);
      case SortOption.newestRegistered:
        transformQuery = query.order('created_at', ascending: false);
    }

    // 6. Server-side Pagination
    transformQuery = transformQuery.range(filter.offset, filter.offset + filter.limit - 1);

    final response = await supabase.retry(() => transformQuery);
    return List<Map<String, dynamic>>.from(response);
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

    // Use count() method correctly for Supabase 2.x
    final response = await supabase.retry(() => query.count(CountOption.exact));
    return response.count;
  } catch (e) {
    return 0;
  }
});
"""

with open(path, 'w', encoding='utf-8', newline='\n') as f:
    f.write(content)
