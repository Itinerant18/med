import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/role_provider.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/audit/audit_provider.dart';
import 'package:mediflow/shared/widgets/empty_state.dart';
import 'package:mediflow/shared/widgets/error_boundary.dart';

class AuditLogsScreen extends ConsumerStatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  ConsumerState<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends ConsumerState<AuditLogsScreen> {
  final ScrollController _scrollController = ScrollController();
  AuditFilter _filter = const AuditFilter(
    targetTable: 'all',
    action: 'all',
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(auditLogsProvider.notifier).loadMore();
    }
  }

  Future<void> _refresh() {
    return ref.read(auditLogsProvider.notifier).refresh();
  }

  Future<void> _showAdvancedFilters() async {
    final result = await showModalBottomSheet<AuditFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AuditFilterSheet(initialFilter: _filter),
    );

    if (result == null || !mounted) return;
    setState(() => _filter = result);
    await ref.read(auditLogsProvider.notifier).applyFilter(result);
  }

  @override
  Widget build(BuildContext context) {
    final isHeadDoctor = ref.watch(isHeadDoctorProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        actions: [
          IconButton(
            tooltip: 'Filter',
            onPressed: _showAdvancedFilters,
            icon: const Icon(AppIcons.filter_list_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(AppIcons.refresh_rounded),
          ),
        ],
      ),
      backgroundColor: AppTheme.bgColor,
      body: !isAdmin
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: _NoAccessCard(),
            )
          : Column(
              children: [
                if (isHeadDoctor)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _TopFilterBar(
                      filter: _filter,
                      onChanged: (nextFilter) async {
                        setState(() => _filter = nextFilter);
                        await ref
                            .read(auditLogsProvider.notifier)
                            .applyFilter(nextFilter);
                      },
                    ),
                  ),
                Expanded(
                  child: ref.watch(auditLogsProvider).whenWithBoundary(
                        loading: () => _AuditLoadingList(
                          controller: _scrollController,
                        ),
                        onRetry: _refresh,
                        contextLabel: 'audit_logs',
                        errorTitle: 'Failed to load audit logs',
                        data: (state) => _AuditList(
                          controller: _scrollController,
                          state: state,
                        ),
                      ),
                ),
              ],
            ),
    );
  }
}

class _TopFilterBar extends StatelessWidget {
  const _TopFilterBar({
    required this.filter,
    required this.onChanged,
  });

  final AuditFilter filter;
  final ValueChanged<AuditFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final tableOptions = [
      ('all', 'All'),
      ('patients', 'Patients'),
      ('doctors', 'Doctors'),
      ('visits', 'Visits'),
    ];
    final actionOptions = [
      ('all', 'All'),
      ('INSERT', 'Created'),
      ('UPDATE', 'Updated'),
      ('DELETE', 'Deleted'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...tableOptions.map(
            (option) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _FilterChip(
                label: option.$2,
                selected: filter.targetTable == option.$1,
                onTap: () => onChanged(
                  AuditFilter(
                    targetTable: option.$1,
                    actorId: filter.actorId,
                    action: filter.action,
                    dateFrom: filter.dateFrom,
                    dateTo: filter.dateTo,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ...actionOptions.map(
            (option) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _FilterChip(
                label: option.$2,
                selected: filter.action == option.$1,
                onTap: () => onChanged(
                  AuditFilter(
                    targetTable: filter.targetTable,
                    actorId: filter.actorId,
                    action: option.$1,
                    dateFrom: filter.dateFrom,
                    dateTo: filter.dateTo,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      backgroundColor: selected
          ? AppTheme.primaryTeal.withValues(alpha: 0.12)
          : Colors.white.withValues(alpha: 0.7),
      side: BorderSide(
        color: selected
            ? AppTheme.primaryTeal
            : AppTheme.textMuted.withValues(alpha: 0.16),
      ),
      label: Text(
        label,
        style: TextStyle(
          color: selected ? AppTheme.primaryTeal : AppTheme.textMuted,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AuditLoadingList extends StatelessWidget {
  const _AuditLoadingList({required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const NeuCard(
        padding: EdgeInsets.all(12),
        child: NeuShimmer(width: double.infinity, height: 72),
      ),
    );
  }
}

class _AuditList extends StatelessWidget {
  const _AuditList({
    required this.controller,
    required this.state,
  });

  final ScrollController controller;
  final AuditState state;

  @override
  Widget build(BuildContext context) {
    if (state.entries.isEmpty) {
      return ListView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: const [
          SizedBox(height: 80),
          EmptyState(
            icon: AppIcons.document_empty,
            title: 'No audit activity found',
            subtitle:
                'Audit events will appear here as staff make changes.',
          ),
        ],
      );
    }

    return ListView.builder(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: state.entries.length + 1,
      itemBuilder: (context, index) {
        if (index == state.entries.length) {
          if (!state.hasMore) {
            return const SizedBox(height: 8);
          }
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryTeal),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _AuditCard(entry: state.entries[index]),
        );
      },
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.entry});

  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d · HH:mm');

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _AuditDetailSheet(entry: entry),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border(
            left: BorderSide(color: entry.actionColor, width: 4),
          ),
        ),
        child: NeuCard(
          borderRadius: 18,
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: entry.actionColor.withValues(alpha: 0.1),
                child: Icon(
                  entry.actionIcon,
                  color: entry.actionColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.actorName,
                            style: const TextStyle(
                              color: AppTheme.textColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: entry.actionColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            entry.actionLabel,
                            style: TextStyle(
                              color: entry.actionColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.description.isEmpty
                          ? 'No description'
                          : entry.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatter.format(entry.createdAt.toLocal()),
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      entry.targetTable.isEmpty ? 'system' : entry.targetTable,
                      style: const TextStyle(
                        color: AppTheme.textColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuditDetailSheet extends StatelessWidget {
  const _AuditDetailSheet({required this.entry});

  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, controller) {
        return NeuCard(
          borderRadius: 28,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                entry.actionColor.withValues(alpha: 0.1),
                            child: Icon(
                              entry.actionIcon,
                              color: entry.actionColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.description.isEmpty
                                  ? entry.actionLabel
                                  : entry.description,
                              style: const TextStyle(
                                color: AppTheme.textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _MetaRow(label: 'Actor', value: entry.actorName),
                      _MetaRow(
                        label: 'Role',
                        value: entry.actorRole.isEmpty
                            ? 'Unknown'
                            : entry.actorRole,
                      ),
                      _MetaRow(label: 'Action', value: entry.actionLabel),
                      _MetaRow(
                        label: 'Table',
                        value: entry.targetTable.isEmpty
                            ? 'system'
                            : entry.targetTable,
                      ),
                      _MetaRow(
                        label: 'Target ID',
                        value: entry.targetId ?? 'N/A',
                      ),
                      _MetaRow(
                        label: 'Date',
                        value: DateFormat('MMM d, yyyy · HH:mm')
                            .format(entry.createdAt.toLocal()),
                      ),
                      if (entry.oldData != null && entry.newData != null) ...[
                        const SizedBox(height: 20),
                        const SectionTitle(
                          title: 'Changed Fields',
                          icon: AppIcons.compare_arrows_rounded,
                        ),
                        _DiffView(
                          oldData: entry.oldData!,
                          newData: entry.newData!,
                        ),
                      ],
                      if ((entry.oldData != null && entry.newData == null) ||
                          (entry.oldData == null && entry.newData != null)) ...[
                        const SizedBox(height: 20),
                        const SectionTitle(
                          title: 'Payload',
                          icon: AppIcons.data_object_rounded,
                        ),
                        _PayloadCard(
                          data: entry.newData ?? entry.oldData!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: NeuButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DiffView extends StatelessWidget {
  const _DiffView({
    required this.oldData,
    required this.newData,
  });

  final Map<String, dynamic> oldData;
  final Map<String, dynamic> newData;

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, Map<String, dynamic>>>[];

    for (final entry in newData.entries) {
      final oldValue = oldData[entry.key];
      if (_normalizedValue(oldValue) == _normalizedValue(entry.value)) {
        continue;
      }
      rows.add(
        MapEntry(
          entry.key,
          {
            'old': oldValue,
            'new': entry.value,
          },
        ),
      );
    }

    if (rows.isEmpty) {
      return const Text(
        'No field-level differences available.',
        style: TextStyle(
          color: AppTheme.textMuted,
          fontSize: 13,
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: SingleChildScrollView(
        child: Column(
          children: rows.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NeuCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        row.key,
                        style: const TextStyle(
                          color: AppTheme.textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayValue(row.value['old']),
                            style: const TextStyle(
                              color: AppTheme.errorColor,
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _displayValue(row.value['new']),
                            style: const TextStyle(
                              color: AppTheme.successColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _normalizedValue(dynamic value) => jsonEncode(value);

  String _displayValue(dynamic value) {
    if (value == null) return 'null';
    if (value is Map || value is List) {
      return jsonEncode(value);
    }
    return value.toString();
  }
}

class _PayloadCard extends StatelessWidget {
  const _PayloadCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        const JsonEncoder.withIndent('  ').convert(data),
        style: const TextStyle(
          color: AppTheme.textColor,
          fontSize: 12,
          height: 1.45,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditFilterSheet extends ConsumerStatefulWidget {
  const _AuditFilterSheet({required this.initialFilter});

  final AuditFilter initialFilter;

  @override
  ConsumerState<_AuditFilterSheet> createState() => _AuditFilterSheetState();
}

class _AuditFilterSheetState extends ConsumerState<_AuditFilterSheet> {
  late String _selectedTable;
  late String _selectedAction;
  String? _selectedActorId;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _selectedTable = widget.initialFilter.targetTable;
    _selectedAction = widget.initialFilter.action;
    _selectedActorId = widget.initialFilter.actorId;
    _dateFrom = widget.initialFilter.dateFrom;
    _dateTo = widget.initialFilter.dateTo;
  }

  @override
  Widget build(BuildContext context) {
    final isHeadDoctor = ref.watch(isHeadDoctorProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, controller) {
        return NeuCard(
          borderRadius: 28,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: SingleChildScrollView(
            controller: controller,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.textMuted.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const SectionTitle(
                  title: 'Advanced Filters',
                  icon: AppIcons.filter_alt_outlined,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _selectedTable,
                  decoration: const InputDecoration(labelText: 'Table'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(
                      value: 'patients',
                      child: Text('Patients'),
                    ),
                    DropdownMenuItem(
                      value: 'doctors',
                      child: Text('Doctors'),
                    ),
                    DropdownMenuItem(value: 'visits', child: Text('Visits')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedTable = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedAction,
                  decoration: const InputDecoration(labelText: 'Action'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'INSERT', child: Text('Created')),
                    DropdownMenuItem(value: 'UPDATE', child: Text('Updated')),
                    DropdownMenuItem(value: 'DELETE', child: Text('Deleted')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedAction = value);
                  },
                ),
                if (isHeadDoctor) ...[
                  const SizedBox(height: 12),
                  ref.watch(
                    auditActorsProvider((page: 0, pageSize: 100)),
                  ).when(
                        loading: () => const NeuShimmer(
                          width: double.infinity,
                          height: 56,
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (actors) {
                          return DropdownButtonFormField<String?>(
                            initialValue: _selectedActorId,
                            decoration:
                                const InputDecoration(labelText: 'Actor'),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All Actors'),
                              ),
                              ...actors.map(
                                (actor) => DropdownMenuItem<String?>(
                                  value: actor['actor_id'],
                                  child: Text(actor['actor_name'] ?? 'Unknown'),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedActorId = value);
                            },
                          );
                        },
                      ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'From',
                        value: _dateFrom,
                        onTap: () async {
                          final picked = await _pickDate(_dateFrom);
                          if (picked != null) {
                            setState(() => _dateFrom = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateField(
                        label: 'To',
                        value: _dateTo,
                        onTap: () async {
                          final picked = await _pickDate(_dateTo);
                          if (picked != null) {
                            setState(() => _dateTo = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop(
                            const AuditFilter(
                              targetTable: 'all',
                              action: 'all',
                            ),
                          );
                        },
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NeuButton(
                        onPressed: () {
                          Navigator.of(context).pop(
                            AuditFilter(
                              targetTable: _selectedTable,
                              actorId: _selectedActorId,
                              action: _selectedAction,
                              dateFrom: _dateFrom,
                              dateTo: _dateTo == null
                                  ? null
                                  : DateTime(
                                      _dateTo!.year,
                                      _dateTo!.month,
                                      _dateTo!.day,
                                      23,
                                      59,
                                      59,
                                    ),
                            ),
                          );
                        },
                        child: const Text(
                          'Apply',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<DateTime?> _pickDate(DateTime? initialValue) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initialValue ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          value == null ? 'Any' : DateFormat('MMM d, yyyy').format(value!),
          style: const TextStyle(
            color: AppTheme.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _NoAccessCard extends StatelessWidget {
  const _NoAccessCard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: NeuCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.lock_outline_rounded,
              size: 32,
              color: AppTheme.textMuted,
            ),
            SizedBox(height: 12),
            Text(
              'No access',
              style: TextStyle(
                color: AppTheme.textColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Audit logs are available only for doctors and head doctors.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

