import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/core/role_provider.dart';
import 'package:mediflow/features/patients/patient_list_provider.dart';
import 'package:go_router/go_router.dart';

class PatientListScreen extends ConsumerStatefulWidget {
  const PatientListScreen({super.key});

  @override
  ConsumerState<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends ConsumerState<PatientListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  String _searchQuery = '';
  HealthSchemeFilter _healthScheme = HealthSchemeFilter.all;
  PriorityFilter _priority = PriorityFilter.all;
  DateRangeFilter _dateRange = DateRangeFilter.allTime;
  VisitTypeFilter _visitType = VisitTypeFilter.all;
  SortOption _sortOption = SortOption.mostRecentVisit;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim());
    });
  }

  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            void refreshSheet() => sheetSetState(() {});

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSheetHeader('Health Scheme'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildChoiceChip(
                            label: 'All',
                            selected: _healthScheme == HealthSchemeFilter.all,
                            onSelected: () {
                              setState(
                                  () => _healthScheme = HealthSchemeFilter.all);
                              refreshSheet();
                            },
                          ),
                          _buildChoiceChip(
                            label: 'Insurance',
                            selected:
                                _healthScheme == HealthSchemeFilter.insurance,
                            onSelected: () {
                              setState(() =>
                                  _healthScheme = HealthSchemeFilter.insurance);
                              refreshSheet();
                            },
                          ),
                          _buildChoiceChip(
                            label: 'Cash',
                            selected: _healthScheme == HealthSchemeFilter.cash,
                            onSelected: () {
                              setState(() =>
                                  _healthScheme = HealthSchemeFilter.cash);
                              refreshSheet();
                            },
                          ),
                          _buildChoiceChip(
                            label: 'Sastho Sathi',
                            selected:
                                _healthScheme == HealthSchemeFilter.sasthoSathi,
                            onSelected: () {
                              setState(() => _healthScheme =
                                  HealthSchemeFilter.sasthoSathi);
                              refreshSheet();
                            },
                          ),
                          _buildChoiceChip(
                            label: 'Other',
                            selected: _healthScheme == HealthSchemeFilter.other,
                            onSelected: () {
                              setState(() =>
                                  _healthScheme = HealthSchemeFilter.other);
                              refreshSheet();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildSheetHeader('Priority'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildChoiceChip(
                            label: 'All',
                            selected: _priority == PriorityFilter.all,
                            onSelected: () {
                              setState(() => _priority = PriorityFilter.all);
                              refreshSheet();
                            },
                          ),
                          _buildChoiceChip(
                            label: 'High Priority only',
                            selected: _priority == PriorityFilter.highOnly,
                            onSelected: () {
                              setState(
                                  () => _priority = PriorityFilter.highOnly);
                              refreshSheet();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildSheetHeader('Date Range'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildChoiceChip(
                            label: 'Last 7 days',
                            selected: _dateRange == DateRangeFilter.last7Days,
                            onSelected: () {
                              setState(
                                  () => _dateRange = DateRangeFilter.last7Days);
                              refreshSheet();
                            },
                          ),
                          _buildChoiceChip(
                            label: 'Last 30 days',
                            selected: _dateRange == DateRangeFilter.last30Days,
                            onSelected: () {
                              setState(() =>
                                  _dateRange = DateRangeFilter.last30Days);
                              refreshSheet();
                            },
                          ),
                          _buildChoiceChip(
                            label: 'Last 3 months',
                            selected: _dateRange == DateRangeFilter.last3Months,
                            onSelected: () {
                              setState(() =>
                                  _dateRange = DateRangeFilter.last3Months);
                              refreshSheet();
                            },
                          ),
                          _buildChoiceChip(
                            label: 'All time',
                            selected: _dateRange == DateRangeFilter.allTime,
                            onSelected: () {
                              setState(
                                  () => _dateRange = DateRangeFilter.allTime);
                              refreshSheet();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildSheetHeader('Visit Type'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildChoiceChip(
                            label: 'All',
                            selected: _visitType == VisitTypeFilter.all,
                            onSelected: () {
                              setState(() => _visitType = VisitTypeFilter.all);
                              refreshSheet();
                            },
                          ),
                          _buildChoiceChip(
                            label: 'OPD',
                            selected: _visitType == VisitTypeFilter.opd,
                            onSelected: () {
                              setState(() => _visitType = VisitTypeFilter.opd);
                              refreshSheet();
                            },
                          ),
                          _buildChoiceChip(
                            label: 'IPD',
                            selected: _visitType == VisitTypeFilter.ipd,
                            onSelected: () {
                              setState(() => _visitType = VisitTypeFilter.ipd);
                              refreshSheet();
                            },
                          ),
                          _buildChoiceChip(
                            label: 'Emergency',
                            selected: _visitType == VisitTypeFilter.emergency,
                            onSelected: () {
                              setState(
                                  () => _visitType = VisitTypeFilter.emergency);
                              refreshSheet();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: NeuButton(
                          onPressed: _clearAllFilters,
                          child: const Text('Clear All Filters'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _clearAllFilters() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _healthScheme = HealthSchemeFilter.all;
      _priority = PriorityFilter.all;
      _dateRange = DateRangeFilter.allTime;
      _visitType = VisitTypeFilter.all;
      _sortOption = SortOption.mostRecentVisit;
    });
  }

  SearchFilter _buildFilter() {
    return SearchFilter(
      query: _searchQuery,
      healthScheme: _healthScheme,
      priority: _priority,
      dateRange: _dateRange,
      visitType: _visitType,
      sortOption: _sortOption,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = _buildFilter();
    final patientsAsync = ref.watch(roleAwarePatientsProvider(filter));
    final totalAsync = ref.watch(patientTotalCountProvider);
    final isAdmin = ref.watch(isAdminProvider);

    final totalCount = totalAsync.value ?? 0;
    final shownCount = patientsAsync.value?.length ?? 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Client Directory',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort, color: AppTheme.primaryTeal),
            onSelected: (value) => setState(() => _sortOption = value),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: SortOption.nameAsc,
                child: Text('Name A-Z'),
              ),
              PopupMenuItem(
                value: SortOption.nameDesc,
                child: Text('Name Z-A'),
              ),
              PopupMenuItem(
                value: SortOption.mostRecentVisit,
                child: Text('Most Recent Visit'),
              ),
              PopupMenuItem(
                value: SortOption.highPriorityFirst,
                child: Text('High Priority First'),
              ),
              PopupMenuItem(
                value: SortOption.newestRegistered,
                child: Text('Newest Registered'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Sticky Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.bgColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Theme.of(context)
                        .scaffoldBackgroundColor
                        .withValues(alpha: 0.8),
                    blurRadius: 10,
                    offset: const Offset(-2, -2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search by name, phone, email...',
                  prefixIcon:
                      const Icon(Icons.search, color: AppTheme.primaryTeal),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.filter_list,
                        color: AppTheme.primaryTeal),
                    onPressed: _openFilterSheet,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Showing $shownCount of $totalCount patients',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: patientsAsync.when(
              data: (patients) {
                if (patients.isEmpty) {
                  return _buildEmptyState();
                }
                return RefreshIndicator(
                  color: const Color(0xFF1A6B5A),
                  onRefresh: () async {
                    ref.invalidate(roleAwarePatientsProvider(filter));
                  },
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: patients.length,
                    itemBuilder: (context, index) {
                      final patient = patients[index];
                      final bool isHighPriority =
                          patient['is_high_priority'] ?? false;
                      final lastUpdated = patient['last_updated_at'] != null
                          ? DateFormat.yMMMd().format(
                              DateTime.parse(patient['last_updated_at']))
                          : 'Unknown';
                      final lastUpdatedBy =
                          patient['last_updated_by'] ?? 'No edits yet';

                      final phone = (patient['phone'] ?? '').toString();
                      final email = (patient['email'] ?? '').toString();
                      final symptoms = (patient['symptoms'] ?? '').toString();
                      final areaAffected =
                          (patient['area_affected'] ?? '').toString();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isHighPriority
                                  ? Colors.red.withValues(alpha: 0.5)
                                  : Colors.transparent,
                              width: isHighPriority ? 2 : 0,
                            ),
                          ),
                          child: GestureDetector(
                            onTap: () => context
                                .push('/patients/${patient['id']}/detail'),
                            child: NeuCard(
                              borderRadius: 16,
                              padding: EdgeInsets.zero,
                              child: Column(
                                children: [
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      backgroundColor: isHighPriority
                                          ? Colors.red.withValues(alpha: 0.1)
                                          : AppTheme.primaryTeal
                                              .withValues(alpha: 0.1),
                                      child: Icon(
                                          isHighPriority
                                              ? Icons.priority_high_rounded
                                              : Icons.person,
                                          color: isHighPriority
                                              ? Colors.red
                                              : AppTheme.primaryTeal),
                                    ),
                                    title: _buildHighlightedText(
                                      patient['full_name'] ?? 'Unknown',
                                      _searchQuery,
                                      const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                            'ID: ${(patient['id'] ?? '').toString().substring(0, 8)}...'),
                                        Text('Last Visit: $lastUpdated'),
                                        if (phone.isNotEmpty)
                                          _buildHighlightedText(
                                              'Phone: $phone',
                                              _searchQuery,
                                              const TextStyle(fontSize: 12)),
                                        if (email.isNotEmpty)
                                          _buildHighlightedText(
                                              'Email: $email',
                                              _searchQuery,
                                              const TextStyle(fontSize: 12)),
                                        if (symptoms.isNotEmpty)
                                          _buildHighlightedText(
                                              'Symptoms: $symptoms',
                                              _searchQuery,
                                              const TextStyle(fontSize: 12)),
                                        if (areaAffected.isNotEmpty)
                                          _buildHighlightedText(
                                              'Area: $areaAffected',
                                              _searchQuery,
                                              const TextStyle(fontSize: 12)),
                                        const SizedBox(height: 8),
                                        _buildServiceBadge(
                                            patient['service_status'] ??
                                                'Pending'),
                                      ],
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: AppTheme.primaryTeal),
                                      onPressed: () => context.push(
                                          '/patients/edit/${patient['id']}'),
                                    ),
                                  ),
                                  // REQUIREMENT 4: Audit info footer
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 12),
                                    child: Row(
                                      children: [
                                        Icon(
                                            isAdmin
                                                ? Icons.person_add_alt_1_rounded
                                                : Icons.access_time,
                                            size: 14,
                                            color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            patient['last_updated_by'] != null
                                                ? isAdmin
                                                    ? 'Added by Dr. $lastUpdatedBy on ${DateFormat('MMM d, HH:mm').format(DateTime.parse(patient['last_updated_at']))}'
                                                    : 'Last updated on ${DateFormat('MMM d, HH:mm').format(DateTime.parse(patient['last_updated_at']))}'
                                                : 'No edits yet',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.primaryTeal)),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryTeal,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/patients/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Patient',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 6,
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        color: selected ? AppTheme.primaryTeal : Colors.grey.shade800,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildSheetHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF718096),
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query, TextStyle style) {
    if (query.isEmpty) {
      return Text(text, style: style);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: style.copyWith(
              color: AppTheme.primaryTeal, fontWeight: FontWeight.bold),
        ),
      );
      start = index + query.length;
    }

    return RichText(text: TextSpan(style: style, children: spans));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('No patients found',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Try adjusting your search or filters',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            height: 44,
            child: NeuButton(
              onPressed: _clearAllFilters,
              child: const Text('Clear filters'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceBadge(String status) {
    Color color = AppTheme.primaryTeal;
    if (status.toLowerCase() == 'pending') color = Colors.amber.shade700;
    if (status.toLowerCase() == 'admitted') color = Colors.red.shade400;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        status.toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        color: selected ? AppTheme.primaryTeal : Colors.grey.shade800,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildSheetHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF718096),
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query, TextStyle style) {
    if (query.isEmpty) {
      return Text(text, style: style);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: style.copyWith(
              color: AppTheme.primaryTeal, fontWeight: FontWeight.bold),
        ),
      );
      start = index + query.length;
    }

    return RichText(text: TextSpan(style: style, children: spans));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('No patients found',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Try adjusting your search or filters',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            height: 44,
            child: NeuButton(
              onPressed: _clearAllFilters,
              child: const Text('Clear filters'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceBadge(String status) {
    Color color = AppTheme.primaryTeal;
    if (status.toLowerCase() == 'pending') color = Colors.amber.shade700;
    if (status.toLowerCase() == 'admitted') color = Colors.red.shade400;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        status.toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
