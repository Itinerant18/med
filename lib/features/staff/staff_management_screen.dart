import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/role_provider.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/staff/staff_provider.dart';
import 'package:mediflow/shared/widgets/empty_state.dart';
import 'package:mediflow/models/user_role.dart';
import 'package:mediflow/shared/widgets/confirm_dialog.dart';

class StaffManagementScreen extends ConsumerStatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  ConsumerState<StaffManagementScreen> createState() =>
      _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  StaffFilter _filter = const StaffFilter(
    roleFilter: null,
    statusFilter: 'all',
    searchQuery: '',
  );

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() {
    ref.invalidate(filteredStaffProvider(_filter));
    return ref.read(staffListProvider.notifier).refresh();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _filter = StaffFilter(
          roleFilter: _filter.roleFilter,
          statusFilter: _filter.statusFilter,
          searchQuery: value.trim(),
        );
      });
    });
  }

  void _applyRoleFilter(UserRole? role) {
    setState(() {
      _filter = StaffFilter(
        roleFilter: role,
        statusFilter: _filter.statusFilter,
        searchQuery: _filter.searchQuery,
      );
    });
  }

  void _applyStatusFilter(String status) {
    setState(() {
      _filter = StaffFilter(
        roleFilter: _filter.roleFilter,
        statusFilter: status,
        searchQuery: _filter.searchQuery,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isHeadDoctor = ref.watch(isHeadDoctorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Accounts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(AppIcons.refresh_rounded),
          ),
        ],
      ),
      body: isHeadDoctor
          ? RefreshIndicator(
              color: AppTheme.primaryTeal,
              onRefresh: _refresh,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _TopBar(
                      controller: _searchController,
                      filter: _filter,
                      onSearchChanged: _onSearchChanged,
                      onRoleSelected: _applyRoleFilter,
                      onStatusSelected: _applyStatusFilter,
                    ),
                    const SizedBox(height: 16),
                    _SummaryChips(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, child) {
                          final filteredAsync =
                              ref.watch(filteredStaffProvider(_filter));

                          return filteredAsync.when(
                            loading: () => ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: 6,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, __) => const NeuCard(
                                child: NeuShimmer(
                                  width: double.infinity,
                                  height: 110,
                                ),
                              ),
                            ),
                            error: (error, stack) => ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                NeuCard(
                                  child: Column(
                                    children: [
                                      const Icon(
                                        AppIcons.error_outline_rounded,
                                        color: AppTheme.errorColor,
                                        size: 28,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        error.toString(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: AppTheme.textMuted,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      NeuButton(
                                        onPressed: _refresh,
                                        child: const Text(
                                          'Retry',
                                          style: TextStyle(
                                              color:
                                                  AppTheme.primaryForeground),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            data: (filtered) {
                              if (filtered.isEmpty) {
                                return ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    SizedBox(height: 80),
                                    EmptyState(
                                      icon: AppIcons.group_off_rounded,
                                      title: 'No staff found',
                                      subtitle:
                                          'No team members match the current filters.',
                                    ),
                                  ],
                                );
                              }

                              return ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final member = filtered[index];
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom:
                                          index == filtered.length - 1 ? 0 : 12,
                                    ),
                                    child: _StaffCard(member: member),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const Padding(
              padding: EdgeInsets.all(16),
              child: _RestrictedView(),
            ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.filter,
    required this.onSearchChanged,
    required this.onRoleSelected,
    required this.onStatusSelected,
  });

  final TextEditingController controller;
  final StaffFilter filter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<UserRole?> onRoleSelected;
  final ValueChanged<String> onStatusSelected;

  @override
  Widget build(BuildContext context) {
    final filterLabel = _buildFilterLabel(filter);

    return Row(
      children: [
        Expanded(
          child: NeuTextField(
            controller: controller,
            label: 'Search staff',
            hint: 'Name, email, or phone',
            prefixIcon: const Icon(
              AppIcons.search_rounded,
              color: AppTheme.textMuted,
              size: 20,
            ),
            onChanged: onSearchChanged,
          ),
        ),
        const SizedBox(width: 12),
        PopupMenuButton<_FilterAction>(
          tooltip: 'Filters',
          color: AppTheme.cardBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (selection) {
            switch (selection.kind) {
              case _FilterKind.role:
                onRoleSelected(selection.role);
              case _FilterKind.status:
                onStatusSelected(selection.status ?? 'all');
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              enabled: false,
              child: Text(
                'Role',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const PopupMenuItem(
              value: _FilterAction.role(null),
              child: Text('All Roles'),
            ),
            const PopupMenuItem(
              value: _FilterAction.role(UserRole.headDoctor),
              child: Text('Head Doctor'),
            ),
            const PopupMenuItem(
              value: _FilterAction.role(UserRole.doctor),
              child: Text('Doctor'),
            ),
            const PopupMenuItem(
              value: _FilterAction.role(UserRole.assistant),
              child: Text('Assistant'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              enabled: false,
              child: Text(
                'Status',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const PopupMenuItem(
              value: _FilterAction.status('all'),
              child: Text('All Statuses'),
            ),
            const PopupMenuItem(
              value: _FilterAction.status('approved'),
              child: Text('Approved'),
            ),
            const PopupMenuItem(
              value: _FilterAction.status('pending'),
              child: Text('Pending'),
            ),
            const PopupMenuItem(
              value: _FilterAction.status('rejected'),
              child: Text('Rejected'),
            ),
          ],
          child: NeuCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  AppIcons.tune_rounded,
                  size: 18,
                  color: AppTheme.primaryTeal,
                ),
                const SizedBox(width: 8),
                Text(
                  filterLabel,
                  style: const TextStyle(
                    color: AppTheme.textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _buildFilterLabel(StaffFilter filter) {
    final parts = <String>[];
    if (filter.roleFilter != null) {
      parts.add(filter.roleFilter!.label);
    }
    if (filter.statusFilter != 'all') {
      parts.add(_titleCase(filter.statusFilter));
    }
    return parts.isEmpty ? 'Filters' : parts.join(' • ');
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

class _SummaryChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(staffCountByRoleProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _CountChip(
            label: 'Head Dr',
            roleCount: counts['head_doctor'] ?? const RoleCount(),
            color: AppTheme.primaryTeal,
          ),
          const SizedBox(width: 10),
          _CountChip(
            label: 'Doctors',
            roleCount: counts['doctor'] ?? const RoleCount(),
            color: AppTheme.doctorAccent,
          ),
          const SizedBox(width: 10),
          _CountChip(
            label: 'Assistants',
            roleCount: counts['assistant'] ?? const RoleCount(),
            color: AppTheme.assistantAccent,
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.roleCount,
    required this.color,
  });

  final String label;
  final RoleCount roleCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$label: ${roleCount.total}',
                style: const TextStyle(
                  color: AppTheme.textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (roleCount.pending > 0)
                Text(
                  '${roleCount.active} active · ${roleCount.pending} pending',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.member});

  final StaffMember member;

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(member.role);
    final statusColor = _statusColor(member.approvalStatus);
    final hasPhone = member.phone.trim().isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _StaffDetailSheet(member: member),
        );
      },
      child: NeuCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: roleColor.withValues(alpha: 0.15),
              child: Text(
                _initials(member.fullName),
                style: TextStyle(
                  color: roleColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.fullName,
                    style: const TextStyle(
                      color: AppTheme.textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (member.specialization.trim().isNotEmpty)
                        Text(
                          member.specialization,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      _RolePill(role: member.role),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    member.email,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  if (hasPhone) ...[
                    const SizedBox(height: 4),
                    Text(
                      member.phone,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _StaffDetailSheet extends ConsumerStatefulWidget {
  const _StaffDetailSheet({required this.member});

  final StaffMember member;

  @override
  ConsumerState<_StaffDetailSheet> createState() => _StaffDetailSheetState();
}

class _StaffDetailSheetState extends ConsumerState<_StaffDetailSheet> {
  bool _busy = false;
  late UserRole _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = UserRole.fromString(widget.member.role);
  }

  @override
  Widget build(BuildContext context) {
    final isHeadDoctor = ref.watch(isHeadDoctorProvider);
    final targetRole = UserRole.fromString(widget.member.role);
    final canChangeRole = isHeadDoctor && targetRole != UserRole.headDoctor;
    final joinedAt = widget.member.createdAt != null
        ? DateFormat('MMM d, yyyy').format(widget.member.createdAt!)
        : 'Unknown';

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, controller) {
        return NeuCard(
          borderRadius: 28,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              Container(
                width: 46,
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
                            radius: 28,
                            backgroundColor: _roleColor(widget.member.role)
                                .withValues(alpha: 0.14),
                            child: Text(
                              _StaffCard._initials(widget.member.fullName),
                              style: TextStyle(
                                color: _roleColor(widget.member.role),
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.member.fullName,
                                  style: const TextStyle(
                                    color: AppTheme.textColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _RolePill(role: widget.member.role),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _InfoRow(
                        icon: AppIcons.mail_outline_rounded,
                        label: 'Email',
                        value: widget.member.email,
                      ),
                      _InfoRow(
                        icon: AppIcons.call_outlined,
                        label: 'Phone',
                        value: widget.member.phone.trim().isEmpty
                            ? 'Not provided'
                            : widget.member.phone,
                      ),
                      _InfoRow(
                        icon: AppIcons.calendar_today_rounded,
                        label: 'Joined',
                        value: joinedAt,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            'Phone Verification',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: widget.member.phoneVerified
                                  ? AppTheme.successColor
                                      .withValues(alpha: 0.12)
                                  : AppTheme.warningColor
                                      .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              widget.member.phoneVerified
                                  ? 'Verified'
                                  : 'Unverified',
                              style: TextStyle(
                                color: widget.member.phoneVerified
                                    ? AppTheme.successColor
                                    : AppTheme.warningColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const SectionTitle(title: 'Actions'),
                      if (canChangeRole) ...[
                        DropdownButtonFormField<UserRole>(
                          initialValue: _selectedRole == UserRole.headDoctor
                              ? UserRole.doctor
                              : _selectedRole,
                          items: const [
                            DropdownMenuItem(
                              value: UserRole.doctor,
                              child: Text('Doctor'),
                            ),
                            DropdownMenuItem(
                              value: UserRole.assistant,
                              child: Text('Assistant'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Change Role',
                          ),
                          onChanged: _busy
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() => _selectedRole = value);
                                },
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: NeuButton(
                            isLoading: _busy,
                            onPressed: _busy || _selectedRole == targetRole
                                ? null
                                : () => _runAction(
                                      description:
                                          'Change role for ${widget.member.fullName} to ${_selectedRole.label}?',
                                      operation: () => ref
                                          .read(staffListProvider.notifier)
                                          .updateRole(
                                            widget.member.id,
                                            _selectedRole,
                                          ),
                                      successMessage:
                                          'Role updated successfully.',
                                    ),
                            child: const Text(
                              'Update Role',
                              style:
                                  TextStyle(color: AppTheme.primaryForeground),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          if (widget.member.approvalStatus == 'approved')
                            _ActionButton(
                              label: 'Suspend Account',
                              icon: AppIcons.block_rounded,
                              color: AppTheme.errorColor,
                              busy: _busy,
                              onPressed: () => _runAction(
                                description:
                                    'Suspend ${widget.member.fullName}? The account will be marked as rejected.',
                                operation: () => ref
                                    .read(staffListProvider.notifier)
                                    .suspendAccount(widget.member.id),
                                successMessage: 'Account suspended.',
                              ),
                            ),
                          if (widget.member.approvalStatus == 'rejected')
                            _ActionButton(
                              label: 'Reinstate Account',
                              icon: AppIcons.refresh_rounded,
                              color: AppTheme.successColor,
                              busy: _busy,
                              onPressed: () => _runAction(
                                description:
                                    'Reinstate ${widget.member.fullName}? The account will be approved again.',
                                operation: () => ref
                                    .read(staffListProvider.notifier)
                                    .reinstateAccount(widget.member.id),
                                successMessage: 'Account reinstated.',
                              ),
                            ),
                          _ActionButton(
                            label: 'Delete Account',
                            icon: AppIcons.delete_outline_rounded,
                            color: AppTheme.errorColor,
                            busy: _busy,
                            onPressed: () => _runAction(
                              description:
                                  'Delete ${widget.member.fullName} from the staff table? This will not remove the Supabase Auth user.',
                              operation: () => ref
                                  .read(staffListProvider.notifier)
                                  .deleteAccount(widget.member.id),
                              successMessage:
                                  'Account deleted from staff list.',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _runAction({
    required String description,
    required Future<void> Function() operation,
    required String successMessage,
  }) async {
    final confirmed = await _confirmAction(description);
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await operation();
      if (!mounted) return;
      AppSnackbar.showSuccess(context, successMessage);
      context.pop();
    } catch (error) {
      if (!mounted) return;
      AppSnackbar.showError(context, error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> _confirmAction(String description) async {
    final result = await ConfirmDialog.show(
      context,
      title: 'Confirm action',
      message: description,
      confirmLabel: 'Proceed',
      isDestructive: true,
    );

    return result;
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.busy,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _roleLabel(role),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RestrictedView extends StatelessWidget {
  const _RestrictedView();

  void _showRequestAccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Request Access', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'Staff management is restricted to the Head Doctor. If you believe your role should be updated, please contact the hospital administration or your department lead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: NeuCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              AppIcons.lock_outline_rounded,
              color: AppTheme.warningColor,
              size: 42,
            ),
            const SizedBox(height: 16),
            const Text(
              'Access Restricted',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Only the Head Doctor can manage staff accounts and roles.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: NeuButton(
                onPressed: () => _showRequestAccessDialog(context),
                child: const Text(
                  'Request Access',
                  style: TextStyle(color: AppTheme.surfaceWhite, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


enum _FilterKind { role, status }

class _FilterAction {
  const _FilterAction.role(this.role)
      : kind = _FilterKind.role,
        status = null;

  const _FilterAction.status(this.status)
      : kind = _FilterKind.status,
        role = null;

  final _FilterKind kind;
  final UserRole? role;
  final String? status;
}

Color _roleColor(String role) {
  switch (role) {
    case 'head_doctor':
      return AppTheme.primaryTeal;
    case 'doctor':
      return AppTheme.doctorAccent;
    case 'assistant':
      return AppTheme.assistantAccent;
    default:
      return AppTheme.textMuted;
  }
}

String _roleLabel(String role) {
  switch (role) {
    case 'head_doctor':
      return 'Head Doctor';
    case 'doctor':
      return 'Doctor';
    case 'assistant':
      return 'Assistant';
    default:
      return role;
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'approved':
      return AppTheme.successColor;
    case 'pending':
      return AppTheme.warningColor;
    case 'rejected':
      return AppTheme.errorColor;
    default:
      return AppTheme.textMuted;
  }
}
