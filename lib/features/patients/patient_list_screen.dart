// lib/features/patients/patient_list_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/core/role_provider.dart';
import 'package:mediflow/features/patients/patient_list_provider.dart'; import 'package:mediflow/features/patients/patient_permissions.dart'; import 'package:mediflow/features/auth/auth_provider.dart';
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

  bool get _hasActiveFilters =>
      _healthScheme != HealthSchemeFilter.all ||
      _priority != PriorityFilter.all ||
      _dateRange != DateRangeFilter.allTime ||
      _visitType != VisitTypeFilter.all;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _searchQuery = value.trim());
    });
  }

  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _FilterSheet(
        healthScheme: _healthScheme,
        priority: _priority,
        dateRange: _dateRange,
        visitType: _visitType,
        onApply: ({
          required HealthSchemeFilter healthScheme,
          required PriorityFilter priority,
          required DateRangeFilter dateRange,
          required VisitTypeFilter visitType,
        }) {
          setState(() {
            _healthScheme = healthScheme;
            _priority = priority;
            _dateRange = dateRange;
            _visitType = visitType;
          });
        },
        onClear: _clearAllFilters,
      ),
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

  SearchFilter _buildFilter() => SearchFilter(
        query: _searchQuery,
        healthScheme: _healthScheme,
        priority: _priority,
        dateRange: _dateRange,
        visitType: _visitType,
        sortOption: _sortOption,
      );

  Future<void> _openPatientForm(String route) async {
    final filter = _buildFilter();
    final changed = await context.push<bool>(route);
    if (changed == true && mounted) {
      ref.invalidate(roleAwarePatientsProvider(filter));
      ref.invalidate(patientTotalCountProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = _buildFilter();
    final patientsAsync = ref.watch(roleAwarePatientsProvider(filter));
    final totalAsync = ref.watch(patientTotalCountProvider);
    final isAdmin = ref.watch(isAdminProvider); final authState = ref.watch(authNotifierProvider).value;

    final totalCount = totalAsync.value ?? 0;
    final shownCount = patientsAsync.value?.length ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text('Patients',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Sort button
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort_rounded, color: AppTheme.primaryTeal),
            tooltip: 'Sort',
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) => setState(() => _sortOption = value),
            itemBuilder: (context) => [
              _sortItem(SortOption.mostRecentVisit, 'Most Recent',
                  Icons.access_time_rounded),
              _sortItem(
                  SortOption.nameAsc, 'Name A→Z', Icons.sort_by_alpha_rounded),
              _sortItem(
                  SortOption.nameDesc, 'Name Z→A', Icons.sort_by_alpha_rounded),
              _sortItem(SortOption.highPriorityFirst, 'High Priority First',
                  Icons.priority_high_rounded),
              _sortItem(SortOption.newestRegistered, 'Newest Registered',
                  Icons.person_add_rounded),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search Bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.bgColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.white,
                            offset: Offset(-3, -3),
                            blurRadius: 8),
                        BoxShadow(
                            color: Color(0xFFA3B1C6),
                            offset: Offset(3, 3),
                            blurRadius: 8),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(
                          fontSize: 14, color: AppTheme.textColor),
                      decoration: InputDecoration(
                        hintText: 'Search by name, phone, symptoms...',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: AppTheme.textMuted),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AppTheme.primaryTeal, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    size: 18, color: AppTheme.textMuted),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Filter button with active indicator
                GestureDetector(
                  onTap: _openFilterSheet,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _hasActiveFilters
                          ? AppTheme.primaryTeal
                          : AppTheme.bgColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.white,
                            offset: Offset(-3, -3),
                            blurRadius: 8),
                        BoxShadow(
                            color: Color(0xFFA3B1C6),
                            offset: Offset(3, 3),
                            blurRadius: 8),
                      ],
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: _hasActiveFilters
                          ? Colors.white
                          : AppTheme.primaryTeal,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Count bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '$shownCount of $totalCount patients',
                  style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
                if (_hasActiveFilters || _searchQuery.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _clearAllFilters,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Clear filters',
                        style: TextStyle(
                          color: AppTheme.primaryTeal,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 4),

          // ── Patient List ──
          Expanded(
            child: patientsAsync.when(
              loading: () => _buildLoadingList(),
              error: (err, _) => _buildError(err),
              data: (patients) {
                if (patients.isEmpty) return _buildEmptyState();
                return RefreshIndicator(
                  color: AppTheme.primaryTeal,
                  backgroundColor: AppTheme.bgColor,
                  onRefresh: () async {
                    ref.invalidate(roleAwarePatientsProvider(filter));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: patients.length,
                    itemBuilder: (context, index) => _PatientCard(
                      patient: patients[index],
                      searchQuery: _searchQuery,
                      isAdmin: isAdmin, authState: authState,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: !PatientPermissions.canCreatePatient(authState) ? null : FloatingActionButton.extended(
        heroTag: 'patient-list-new-patient',
        backgroundColor: AppTheme.primaryTeal,
        foregroundColor: Colors.white,
        onPressed: () => _openPatientForm('/patients/new'),
        icon: const Icon(Icons.person_add_rounded, size: 20),
        label: const Text('New Patient',
            style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 4,
      ),
    );
  }

  PopupMenuItem<SortOption> _sortItem(
      SortOption value, String label, IconData icon) {
    final isSelected = _sortOption == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: isSelected ? AppTheme.primaryTeal : AppTheme.textMuted),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.primaryTeal : AppTheme.textColor,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            const Icon(Icons.check_rounded,
                size: 16, color: AppTheme.primaryTeal),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: 5,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child:
            NeuShimmer(width: double.infinity, height: 100, borderRadius: 16),
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: NeuCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 12),
              const Text('Failed to load patients',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                error.toString().length > 80
                    ? '${error.toString().substring(0, 80)}...'
                    : error.toString(),
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _hasActiveFilters
                ? 'No matching patients'
                : 'No patients yet',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppTheme.textColor),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty || _hasActiveFilters
                ? 'Try adjusting your search or filters'
                : 'Tap the button below to add your first patient',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty || _hasActiveFilters) ...[
            const SizedBox(height: 20),
            NeuButton(
              onPressed: _clearAllFilters,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              child: const Text('Clear Filters',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Patient Card ──────────────────────────────────────────────────────────────

class _PatientCard extends StatelessWidget {
  final Map<String, dynamic> patient;
  final String searchQuery;
  final bool isAdmin; final AuthUserState? authState;

  const _PatientCard({
    required this.patient,
    required this.searchQuery,
    required this.isAdmin, required this.authState,
  });

  @override
  Widget build(BuildContext context) {
    final bool isHighPriority = patient['is_high_priority'] ?? false;
    final String name = patient['full_name'] ?? 'Unknown';
    final String phone = patient['phone'] ?? '';
    final String symptoms = patient['symptoms'] ?? '';
    final String scheme = patient['health_scheme'] ?? '';
    final String lastUpdatedBy = patient['last_updated_by'] ?? '';

    String lastUpdated = 'Unknown';
    if (patient['last_updated_at'] != null) {
      try {
        lastUpdated = DateFormat('MMM d, yyyy').format(
          DateTime.parse(patient['last_updated_at']),
        );
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => context.push('/patients/${patient['id']}/detail'),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.bgColor,
            borderRadius: BorderRadius.circular(16),
            border: isHighPriority
                ? Border.all(
                    color: Colors.red.withValues(alpha: 0.4), width: 1.5)
                : null,
            boxShadow: const [
              BoxShadow(
                  color: Colors.white, offset: Offset(-3, -3), blurRadius: 8),
              BoxShadow(
                  color: Color(0xFFA3B1C6),
                  offset: Offset(3, 3),
                  blurRadius: 8),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isHighPriority
                            ? Colors.red.withValues(alpha: 0.1)
                            : AppTheme.primaryTeal.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isHighPriority
                            ? Icons.priority_high_rounded
                            : Icons.person_rounded,
                        color:
                            isHighPriority ? Colors.red : AppTheme.primaryTeal,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HighlightedText(
                            text: name,
                            query: searchQuery,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppTheme.textColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                'ID: ${_shortId(patient['id'])}...',
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.textMuted),
                              ),
                              if (scheme.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                _SchemeBadge(scheme: scheme),
                              ],
                            ],
                          ),
                          if (phone.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            _HighlightedText(
                              text: phone,
                              query: searchQuery,
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                          if (symptoms.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            _HighlightedText(
                              text: 'Symptoms: $symptoms',
                              query: searchQuery,
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textMuted),
                              maxLines: 1,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Edit button
                    if (PatientPermissions.canEditPatient(authState, patient)) IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 18, color: AppTheme.primaryTeal),
                      onPressed: () => context
                          .findAncestorStateOfType<_PatientListScreenState>()
                          ?._openPatientForm('/patients/edit/${patient['id']}'),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      tooltip: 'Edit',
                    ),
                  ],
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(color: Color(0xFFD1D9E6), width: 0.8)),
                ),
                child: Row(
                  children: [
                    _ServiceBadge(
                        status: patient['service_status'] ?? 'Pending'),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          isAdmin && lastUpdatedBy.isNotEmpty
                              ? Icons.person_outline_rounded
                              : Icons.access_time_rounded,
                          size: 12,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isAdmin && lastUpdatedBy.isNotEmpty
                              ? 'by $lastUpdatedBy · $lastUpdated'
                              : lastUpdated,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _shortId(dynamic id) { final s = (id ?? '').toString(); return s.length <= 8 ? s : s.substring(0, 8); } class _SchemeBadge extends StatelessWidget {
  final String scheme;
  const _SchemeBadge({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppTheme.primaryTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        scheme.toUpperCase(),
        style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryTeal),
      ),
    );
  }
}

class _ServiceBadge extends StatelessWidget {
  final String status;
  const _ServiceBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color color = AppTheme.primaryTeal;
    if (s == 'pending') color = Colors.amber.shade700;
    if (s == 'admitted') color = Colors.red.shade400;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(
        status.toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Highlighted Text ──────────────────────────────────────────────────────────

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final int? maxLines;

  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text,
          style: style,
          maxLines: maxLines,
          overflow: maxLines != null ? TextOverflow.ellipsis : null);
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
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: style.copyWith(
          color: AppTheme.primaryTeal,
          fontWeight: FontWeight.w700,
          backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.08),
        ),
      ));
      start = index + query.length;
    }

    return RichText(
      text: TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
    );
  }
}

// ── Filter Sheet ──────────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final HealthSchemeFilter healthScheme;
  final PriorityFilter priority;
  final DateRangeFilter dateRange;
  final VisitTypeFilter visitType;
  final void Function({
    required HealthSchemeFilter healthScheme,
    required PriorityFilter priority,
    required DateRangeFilter dateRange,
    required VisitTypeFilter visitType,
  }) onApply;
  final VoidCallback onClear;

  const _FilterSheet({
    required this.healthScheme,
    required this.priority,
    required this.dateRange,
    required this.visitType,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late HealthSchemeFilter _healthScheme;
  late PriorityFilter _priority;
  late DateRangeFilter _dateRange;
  late VisitTypeFilter _visitType;

  @override
  void initState() {
    super.initState();
    _healthScheme = widget.healthScheme;
    _priority = widget.priority;
    _dateRange = widget.dateRange;
    _visitType = widget.visitType;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        builder: (context, scrollController) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  const Text('Filter Patients',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _healthScheme = HealthSchemeFilter.all;
                        _priority = PriorityFilter.all;
                        _dateRange = DateRangeFilter.allTime;
                        _visitType = VisitTypeFilter.all;
                      });
                      widget.onClear();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Reset All'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterSection('Health Scheme', [
                      _chip(
                          'All',
                          _healthScheme == HealthSchemeFilter.all,
                          () => setState(
                              () => _healthScheme = HealthSchemeFilter.all)),
                      _chip(
                          'Insurance',
                          _healthScheme == HealthSchemeFilter.insurance,
                          () => setState(() =>
                              _healthScheme = HealthSchemeFilter.insurance)),
                      _chip(
                          'Cash',
                          _healthScheme == HealthSchemeFilter.cash,
                          () => setState(
                              () => _healthScheme = HealthSchemeFilter.cash)),
                      _chip(
                          'Sastho Sathi',
                          _healthScheme == HealthSchemeFilter.sasthoSathi,
                          () => setState(() =>
                              _healthScheme = HealthSchemeFilter.sasthoSathi)),
                      _chip(
                          'Other',
                          _healthScheme == HealthSchemeFilter.other,
                          () => setState(
                              () => _healthScheme = HealthSchemeFilter.other)),
                    ]),
                    const SizedBox(height: 20),
                    _buildFilterSection('Priority', [
                      _chip('All', _priority == PriorityFilter.all,
                          () => setState(() => _priority = PriorityFilter.all)),
                      _chip(
                          'High Priority',
                          _priority == PriorityFilter.highOnly,
                          () => setState(
                              () => _priority = PriorityFilter.highOnly)),
                    ]),
                    const SizedBox(height: 20),
                    _buildFilterSection('Date Range', [
                      _chip(
                          'Last 7 days',
                          _dateRange == DateRangeFilter.last7Days,
                          () => setState(
                              () => _dateRange = DateRangeFilter.last7Days)),
                      _chip(
                          'Last 30 days',
                          _dateRange == DateRangeFilter.last30Days,
                          () => setState(
                              () => _dateRange = DateRangeFilter.last30Days)),
                      _chip(
                          'Last 3 months',
                          _dateRange == DateRangeFilter.last3Months,
                          () => setState(
                              () => _dateRange = DateRangeFilter.last3Months)),
                      _chip(
                          'All time',
                          _dateRange == DateRangeFilter.allTime,
                          () => setState(
                              () => _dateRange = DateRangeFilter.allTime)),
                    ]),
                    const SizedBox(height: 20),
                    _buildFilterSection('Visit Type', [
                      _chip(
                          'All',
                          _visitType == VisitTypeFilter.all,
                          () =>
                              setState(() => _visitType = VisitTypeFilter.all)),
                      _chip(
                          'OPD',
                          _visitType == VisitTypeFilter.opd,
                          () =>
                              setState(() => _visitType = VisitTypeFilter.opd)),
                      _chip(
                          'IPD',
                          _visitType == VisitTypeFilter.ipd,
                          () =>
                              setState(() => _visitType = VisitTypeFilter.ipd)),
                      _chip(
                          'Emergency',
                          _visitType == VisitTypeFilter.emergency,
                          () => setState(
                              () => _visitType = VisitTypeFilter.emergency)),
                    ]),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: NeuButton(
                        onPressed: () {
                          widget.onApply(
                            healthScheme: _healthScheme,
                            priority: _priority,
                            dateRange: _dateRange,
                            visitType: _visitType,
                          );
                          Navigator.of(context).pop();
                        },
                        child: const Text('Apply Filters',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title, List<Widget> chips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textMuted,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryTeal.withValues(alpha: 0.1)
              : AppTheme.bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.primaryTeal : const Color(0xFFD1D9E6),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppTheme.primaryTeal : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}
