// lib/features/patients/patient_list_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/supabase_client.dart';

enum HealthSchemeFilter { all, insurance, cash, sasthoSathi, other }

enum PriorityFilter { all, highOnly }

enum DateRangeFilter { last7Days, last30Days, last3Months, allTime }

enum VisitTypeFilter { all, opd, ipd, emergency }

enum SortOption { nameAsc, nameDesc, mostRecentVisit, highPriorityFirst, newestRegistered }

class SearchFilter {
  const SearchFilter({
    required this.query,
    required this.healthScheme,
    required this.priority,
    required this.dateRange,
    required this.visitType,
    required this.sortOption,
  });

  final String query;
  final HealthSchemeFilter healthScheme;
  final PriorityFilter priority;
  final DateRangeFilter dateRange;
  final VisitTypeFilter visitType;
  final SortOption sortOption;

  SearchFilter copyWith({
    String? query,
    HealthSchemeFilter? healthScheme,
    PriorityFilter? priority,
    DateRangeFilter? dateRange,
    VisitTypeFilter? visitType,
    SortOption? sortOption,
  }) {
    return SearchFilter(
      query: query ?? this.query,
      healthScheme: healthScheme ?? this.healthScheme,
      priority: priority ?? this.priority,
      dateRange: dateRange ?? this.dateRange,
      visitType: visitType ?? this.visitType,
      sortOption: sortOption ?? this.sortOption,
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
        other.sortOption == sortOption;
  }

  @override
  int get hashCode => Object.hash(query, healthScheme, priority, dateRange, visitType, sortOption);
}

final patientListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('patients')
      .select()
      .order('last_updated_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

final filteredPatientsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, SearchFilter>((ref, filter) async {
  final supabase = ref.watch(supabaseClientProvider);
  final allPatients = await supabase
      .from('patients')
      .select()
      .order('last_updated_at', ascending: false);

  final patients = List<Map<String, dynamic>>.from(allPatients);
  final filtered =
      patients.where((p) => _matchesFilter(p, filter)).toList();
  _sortPatients(filtered, filter.sortOption);
  return filtered;
});

bool _matchesFilter(Map<String, dynamic> patient, SearchFilter filter) {
  if (!_matchesQuery(patient, filter.query)) return false;
  if (!_matchesHealthScheme(patient, filter.healthScheme)) return false;
  if (!_matchesPriority(patient, filter.priority)) return false;
  if (!_matchesDateRange(patient, filter.dateRange)) return false;
  if (!_matchesVisitType(patient, filter.visitType)) return false;
  return true;
}

bool _matchesQuery(Map<String, dynamic> patient, String query) {
  if (query.trim().isEmpty) return true;
  final normalized = query.toLowerCase();
  final fields = [
    patient['full_name'],
    patient['phone'],
    patient['email'],
    patient['symptoms'],
    patient['area_affected'],
  ];
  return fields.any((field) => (field ?? '').toString().toLowerCase().contains(normalized));
}

bool _matchesHealthScheme(Map<String, dynamic> patient, HealthSchemeFilter filter) {
  if (filter == HealthSchemeFilter.all) return true;
  final scheme = (patient['health_scheme'] ?? '').toString().toLowerCase();
  switch (filter) {
    case HealthSchemeFilter.insurance:
      return scheme == 'insurance';
    case HealthSchemeFilter.cash:
      return scheme == 'cash';
    case HealthSchemeFilter.sasthoSathi:
      return scheme == 'sastho_sathi';
    case HealthSchemeFilter.other:
      return scheme == 'other';
    case HealthSchemeFilter.all:
      return true;
  }
}

bool _matchesPriority(Map<String, dynamic> patient, PriorityFilter filter) {
  if (filter == PriorityFilter.all) return true;
  return (patient['is_high_priority'] ?? false) == true;
}

bool _matchesDateRange(Map<String, dynamic> patient, DateRangeFilter filter) {
  if (filter == DateRangeFilter.allTime) return true;
  final date = _getRelevantDate(patient);
  if (date == null) return false;
  final now = DateTime.now();
  final cutoff = switch (filter) {
    DateRangeFilter.last7Days => now.subtract(const Duration(days: 7)),
    DateRangeFilter.last30Days => now.subtract(const Duration(days: 30)),
    DateRangeFilter.last3Months => now.subtract(const Duration(days: 90)),
    DateRangeFilter.allTime => DateTime(1900),
  };
  return date.isAfter(cutoff);
}

bool _matchesVisitType(Map<String, dynamic> patient, VisitTypeFilter filter) {
  if (filter == VisitTypeFilter.all) return true;
  final raw = (patient['visit_type'] ?? patient['last_visit_type'] ?? '').toString().toLowerCase();
  switch (filter) {
    case VisitTypeFilter.opd:
      return raw == 'opd';
    case VisitTypeFilter.ipd:
      return raw == 'ipd';
    case VisitTypeFilter.emergency:
      return raw == 'emergency';
    case VisitTypeFilter.all:
      return true;
  }
}

void _sortPatients(List<Map<String, dynamic>> patients, SortOption sortOption) {
  int compareNames(Map<String, dynamic> a, Map<String, dynamic> b, {bool ascending = true}) {
    final nameA = (a['full_name'] ?? '').toString().toLowerCase();
    final nameB = (b['full_name'] ?? '').toString().toLowerCase();
    return ascending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
  }

  patients.sort((a, b) {
    switch (sortOption) {
      case SortOption.nameAsc:
        return compareNames(a, b);
      case SortOption.nameDesc:
        return compareNames(a, b, ascending: false);
      case SortOption.mostRecentVisit:
        final dateA = _getRelevantDate(a);
        final dateB = _getRelevantDate(b);
        return _compareDates(dateB, dateA);
      case SortOption.highPriorityFirst:
        final priorityA = (a['is_high_priority'] ?? false) == true;
        final priorityB = (b['is_high_priority'] ?? false) == true;
        if (priorityA != priorityB) return priorityA ? -1 : 1;
        return compareNames(a, b);
      case SortOption.newestRegistered:
        final dateA = _getDateFromField(a, 'created_at');
        final dateB = _getDateFromField(b, 'created_at');
        return _compareDates(dateB, dateA);
    }
  });
}

DateTime? _getRelevantDate(Map<String, dynamic> patient) {
  return _getDateFromField(patient, 'last_visit_at') ??
      _getDateFromField(patient, 'last_visit_date') ??
      _getDateFromField(patient, 'last_updated_at') ??
      _getDateFromField(patient, 'created_at');
}

DateTime? _getDateFromField(Map<String, dynamic> patient, String key) {
  final raw = patient[key];
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

int _compareDates(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}
