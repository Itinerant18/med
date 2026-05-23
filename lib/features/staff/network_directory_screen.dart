import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/features/dr_visits/agents_provider.dart';
import 'package:mediflow/features/staff/external_doctors_provider.dart';
import 'package:mediflow/features/staff/staff_activity_provider.dart';
import 'package:mediflow/models/doctor_model.dart';
import 'package:mediflow/models/user_role.dart';

// Fetches all approved fellow doctors (role='doctor') for the directory.
// All authenticated staff can read this (doctors_select_all RLS policy).
final fellowDoctorsDirectoryProvider =
    FutureProvider.autoDispose<List<DoctorModel>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  try {
    final response = await supabase.retry(
      () => supabase
          .from('doctors')
          .select(
              'id, full_name, specialization, email, phone, role, approval_status')
          .eq('role', UserRole.doctor.databaseValue)
          .eq('approval_status', 'approved')
          .order('full_name'),
    );
    return (response as List)
        .map((json) =>
            DoctorModel.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  } catch (e) {
    throw Exception(AppError.getMessage(e));
  }
});

class NetworkDirectoryScreen extends ConsumerWidget {
  const NetworkDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role =
        ref.watch(authNotifierProvider).valueOrNull?.role ?? UserRole.assistant;

    // Agents see only the external doctors list — no tab bar needed.
    if (role == UserRole.assistant) {
      return const _ExternalDoctorsTab();
    }

    final tabs = <Tab>[];
    final views = <Widget>[];

    if (role == UserRole.headDoctor) {
      tabs.add(const Tab(text: 'Fellow Doctors'));
      views.add(const _InternalStaffTab(isFellowDoctors: true));
    }

    tabs.add(const Tab(text: 'Agents'));
    views.add(const _InternalStaffTab(isFellowDoctors: false));

    tabs.add(const Tab(text: 'External'));
    views.add(const _ExternalDoctorsTab());

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          ColoredBox(
            color: AppTheme.cardBg,
            child: TabBar(
              tabs: tabs,
              labelColor: AppTheme.primaryTeal,
              unselectedLabelColor: AppTheme.textMuted,
              indicatorColor: AppTheme.primaryTeal,
              indicatorWeight: 2.5,
              labelStyle: AppTheme.bodyFont(size: 13, weight: FontWeight.w700),
              unselectedLabelStyle: AppTheme.bodyFont(size: 13),
            ),
          ),
          Expanded(child: TabBarView(children: views)),
        ],
      ),
    );
  }
}

// ── Internal staff tab (Fellow Doctors or Agents) ─────────────────────────────

class _InternalStaffTab extends ConsumerWidget {
  const _InternalStaffTab({required this.isFellowDoctors});

  final bool isFellowDoctors;

  /// Activity visibility: head_doctor sees everyone; fellow doctor sees agents
  /// only (not other doctors); agents see nothing.
  bool _canSeeActivity(UserRole viewer) {
    if (viewer == UserRole.headDoctor) return true;
    if (viewer == UserRole.doctor && !isFellowDoctors) return true;
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = isFellowDoctors
        ? ref.watch(fellowDoctorsDirectoryProvider)
        : ref.watch(agentsProvider);

    final viewerRole = ref.watch(authNotifierProvider).valueOrNull?.role ??
        UserRole.assistant;
    final canSeeActivity = _canSeeActivity(viewerRole);

    final selectedDate = ref.watch(selectedActivityDateProvider);
    final activityAsync =
        canSeeActivity ? ref.watch(staffActivityProvider(selectedDate)) : null;
    final activityMap = activityAsync?.valueOrNull ?? const {};

    return Column(
      children: [
        if (canSeeActivity) const _ActivityDatePill(),
        Expanded(
          child: async.when(
            loading: () => const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primaryTeal)),
            error: (e, _) => _PlaceholderView(
              icon: AppIcons.warning_rounded,
              message: e.toString(),
              iconColor: AppTheme.errorColor,
            ),
            data: (members) {
              if (members.isEmpty) {
                return _PlaceholderView(
                  icon: AppIcons.people_outlined,
                  message: isFellowDoctors
                      ? 'No fellow doctors found.'
                      : 'No agents found.',
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                child: NeuCard(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      horizontalMargin: 12,
                      columnSpacing: 20,
                      headingRowColor: WidgetStateProperty.all(
                        AppTheme.primaryTeal.withValues(alpha: 0.05),
                      ),
                      columns: [
                        DataColumn(
                          label: Text(
                            'Name',
                            style: AppTheme.bodyFont(
                                size: 13,
                                weight: FontWeight.w700,
                                color: AppTheme.primaryTeal),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Role',
                            style: AppTheme.bodyFont(
                                size: 13,
                                weight: FontWeight.w700,
                                color: AppTheme.primaryTeal),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Specialization',
                            style: AppTheme.bodyFont(
                                size: 13,
                                weight: FontWeight.w700,
                                color: AppTheme.primaryTeal),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Phone',
                            style: AppTheme.bodyFont(
                                size: 13,
                                weight: FontWeight.w700,
                                color: AppTheme.primaryTeal),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Email',
                            style: AppTheme.bodyFont(
                                size: 13,
                                weight: FontWeight.w700,
                                color: AppTheme.primaryTeal),
                          ),
                        ),
                        if (canSeeActivity)
                          DataColumn(
                            label: Text(
                              'Activity',
                              style: AppTheme.bodyFont(
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: AppTheme.primaryTeal),
                            ),
                          ),
                        if (canSeeActivity)
                          DataColumn(
                            label: Text(
                              'Actions',
                              style: AppTheme.bodyFont(
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: AppTheme.primaryTeal),
                            ),
                          ),
                      ],
                      rows: members.map((member) {
                        final isDoctor = member.role == UserRole.doctor.databaseValue;
                        final badgeColor =
                            isDoctor ? AppTheme.doctorAccent : AppTheme.assistantAccent;
                        final badgeLabel = isDoctor ? 'Doctor' : 'Agent';
                        final activity = activityMap[member.id];

                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                member.fullName,
                                style: AppTheme.bodyFont(
                                    size: 13, weight: FontWeight.w700),
                              ),
                            ),
                            DataCell(
                              _RoleBadge(label: badgeLabel, color: badgeColor),
                            ),
                            DataCell(
                              Text(
                                member.specialization?.isNotEmpty == true
                                    ? member.specialization!
                                    : '-',
                                style: AppTheme.bodyFont(size: 13),
                              ),
                            ),
                            DataCell(
                              Text(
                                member.phone?.isNotEmpty == true
                                    ? member.phone!
                                    : '-',
                                style: AppTheme.bodyFont(size: 13),
                              ),
                            ),
                            DataCell(
                              Text(
                                member.email?.isNotEmpty == true
                                    ? member.email!
                                    : '-',
                                style: AppTheme.bodyFont(size: 13),
                              ),
                            ),
                            if (canSeeActivity)
                              DataCell(
                                _buildActivitySummary(
                                  isDoctor,
                                  activity,
                                  activityAsync?.isLoading ?? false,
                                ),
                              ),
                            if (canSeeActivity)
                              DataCell(
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(AppIcons.history_rounded,
                                      color: AppTheme.primaryTeal, size: 18),
                                  onPressed: () => _showActivitySheet(
                                      context, member, selectedDate),
                                ),
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActivitySummary(
      bool isDoctor, StaffActivity? activity, bool loading) {
    if (loading && activity == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.2,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Loading…',
            style: AppTheme.bodyFont(size: 11, color: AppTheme.textMuted),
          ),
        ],
      );
    }

    final a = activity;
    if (a == null || a.isEmpty) {
      return Text(
        '-',
        style: AppTheme.bodyFont(size: 11, color: AppTheme.textMuted),
      );
    }

    final chips = <Widget>[];
    if (isDoctor) {
      if (a.drVisits.isNotEmpty) {
        chips.add(_ActivityChip(
          icon: AppIcons.medical_services_rounded,
          color: AppTheme.doctorAccent,
          label:
              '${a.drVisits.length} ${a.drVisits.length == 1 ? "visit" : "visits"}',
        ));
      }
      if (a.followupsAssigned.isNotEmpty) {
        chips.add(_ActivityChip(
          icon: AppIcons.add_task_rounded,
          color: AppTheme.primaryTeal,
          label:
              '${a.followupsAssigned.length} ${a.followupsAssigned.length == 1 ? "follow-up" : "follow-ups"}',
        ));
      }
    } else {
      if (a.outsideVisits.isNotEmpty) {
        chips.add(_ActivityChip(
          icon: AppIcons.local_hospital_rounded,
          color: AppTheme.assistantAccent,
          label:
              '${a.outsideVisits.length} ${a.outsideVisits.length == 1 ? "visit" : "visits"}',
        ));
      }
      if (a.followupsCompleted.isNotEmpty) {
        chips.add(_ActivityChip(
          icon: AppIcons.check_circle_rounded,
          color: AppTheme.successColor,
          label: '${a.followupsCompleted.length} comp.',
        ));
      }
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: chips,
    );
  }

  void _showActivitySheet(
      BuildContext context, DoctorModel member, DateTime selectedDate) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _StaffActivitySheet(
        member: member,
        selectedDate: selectedDate,
      ),
    );
  }
}

// ── Date pill ────────────────────────────────────────────────────────────────

class _ActivityDatePill extends ConsumerWidget {
  const _ActivityDatePill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedActivityDateProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = selectedDate == today;
    final label = isToday
        ? 'Today'
        : DateFormat('EEE, MMM d').format(selectedDate);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Text(
            'Activity on',
            style: AppTheme.bodyFont(
                size: 12, color: AppTheme.textMuted, weight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate:
                      today.subtract(const Duration(days: 365)),
                  lastDate: today,
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                            primary: AppTheme.primaryTeal,
                          ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  ref.read(selectedActivityDateProvider.notifier).state =
                      DateTime(picked.year, picked.month, picked.day);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(AppIcons.calendar_today_rounded,
                        size: 12, color: AppTheme.primaryTeal),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: AppTheme.bodyFont(
                        size: 12,
                        weight: FontWeight.w700,
                        color: AppTheme.primaryTeal,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(AppIcons.arrow_drop_down_rounded,
                        size: 14, color: AppTheme.primaryTeal),
                  ],
                ),
              ),
            ),
          ),
          if (!isToday) ...[
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(AppIcons.clear_rounded,
                  size: 14, color: AppTheme.textMuted),
              tooltip: 'Reset to today',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                  minWidth: 28, minHeight: 28),
              onPressed: () {
                ref.read(selectedActivityDateProvider.notifier).state = today;
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityChip extends StatelessWidget {
  const _ActivityChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTheme.bodyFont(
                size: 11, weight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

// ── External doctors tab ──────────────────────────────────────────────────────

class _ExternalDoctorsTab extends ConsumerWidget {
  const _ExternalDoctorsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(externalDoctorsProvider);

    return Stack(
      children: [
        async.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryTeal)),
          error: (e, _) => _PlaceholderView(
            icon: AppIcons.warning_rounded,
            message: e.toString(),
            iconColor: AppTheme.errorColor,
          ),
          data: (doctors) {
            if (doctors.isEmpty) {
              return const _PlaceholderView(
                icon: AppIcons.person_search_rounded,
                message: 'No external doctors yet.\nTap + to add one.',
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: NeuCard(
                borderRadius: 20,
                padding: const EdgeInsets.all(8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    horizontalMargin: 12,
                    columnSpacing: 20,
                    headingRowColor: WidgetStateProperty.all(
                      AppTheme.primaryTeal.withValues(alpha: 0.05),
                    ),
                    columns: [
                      DataColumn(
                        label: Text(
                          'Name',
                          style: AppTheme.bodyFont(size: 13, weight: FontWeight.w700, color: AppTheme.primaryTeal),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Type',
                          style: AppTheme.bodyFont(size: 13, weight: FontWeight.w700, color: AppTheme.primaryTeal),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Specialization',
                          style: AppTheme.bodyFont(size: 13, weight: FontWeight.w700, color: AppTheme.primaryTeal),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Hospital / Clinic',
                          style: AppTheme.bodyFont(size: 13, weight: FontWeight.w700, color: AppTheme.primaryTeal),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Area (District)',
                          style: AppTheme.bodyFont(size: 13, weight: FontWeight.w700, color: AppTheme.primaryTeal),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Phone',
                          style: AppTheme.bodyFont(size: 13, weight: FontWeight.w700, color: AppTheme.primaryTeal),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Email',
                          style: AppTheme.bodyFont(size: 13, weight: FontWeight.w700, color: AppTheme.primaryTeal),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Status',
                          style: AppTheme.bodyFont(size: 13, weight: FontWeight.w700, color: AppTheme.primaryTeal),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Actions',
                          style: AppTheme.bodyFont(size: 13, weight: FontWeight.w700, color: AppTheme.primaryTeal),
                        ),
                      ),
                    ],
                    rows: doctors.map((doctor) {
                      final isOffline = doctor.id.startsWith('offline_');
                      final canManage = !isOffline && !doctor.fromHistory;
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              doctor.name,
                              style: AppTheme.bodyFont(size: 13, weight: FontWeight.w700),
                            ),
                          ),
                          DataCell(
                            Text(
                              doctor.meetDrType ?? '-',
                              style: AppTheme.bodyFont(size: 13),
                            ),
                          ),
                          DataCell(
                            Text(
                              doctor.specialization ?? '-',
                              style: AppTheme.bodyFont(size: 13),
                            ),
                          ),
                          DataCell(
                            Text(
                              doctor.hospital ?? '-',
                              style: AppTheme.bodyFont(size: 13),
                            ),
                          ),
                          DataCell(
                            Text(
                              doctor.areaDistrict ?? '-',
                              style: AppTheme.bodyFont(size: 13),
                            ),
                          ),
                          DataCell(
                            Text(
                              doctor.phone ?? '-',
                              style: AppTheme.bodyFont(size: 13),
                            ),
                          ),
                          DataCell(
                            Text(
                              doctor.email ?? '-',
                              style: AppTheme.bodyFont(size: 13),
                            ),
                          ),
                          DataCell(
                            isOffline
                                ? const _RoleBadge(label: 'Pending sync', color: AppTheme.warningColor)
                                : doctor.fromHistory
                                    ? const _RoleBadge(label: 'From visits', color: AppTheme.infoColor)
                                    : const _RoleBadge(label: 'Synced', color: AppTheme.primaryTeal),
                          ),
                          DataCell(
                            canManage
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(AppIcons.edit_rounded, color: AppTheme.primaryTeal, size: 18),
                                        onPressed: () => _showEditSheet(context, doctor),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(AppIcons.delete_rounded, color: AppTheme.errorColor, size: 18),
                                        onPressed: () => _confirmDelete(context, ref, doctor),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => _showAddSheet(context),
            backgroundColor: AppTheme.primaryTeal,
            foregroundColor: Colors.white,
            tooltip: 'Add external doctor',
            child: const Icon(AppIcons.add_rounded),
          ),
        ),
      ],
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _AddExternalDoctorSheet(),
    );
  }

  void _showEditSheet(BuildContext context, ExternalDoctor doctor) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditExternalDoctorSheet(doctor: doctor),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ExternalDoctor doctor) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Doctor',
            style: AppTheme.bodyFont(size: 16, weight: FontWeight.w700)),
        content: Text(
          'Remove "${doctor.name}" from the directory?',
          style: AppTheme.bodyFont(size: 14, color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: AppTheme.bodyFont(size: 13, color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(externalDoctorsProvider.notifier).delete(doctor.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString()),
                    backgroundColor: AppTheme.errorColor,
                  ));
                }
              }
            },
            child: Text('Delete',
                style: AppTheme.bodyFont(
                    size: 13,
                    weight: FontWeight.w700,
                    color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}



const List<String> _westBengalDistricts = [
  'Alipurduar',
  'Bankura',
  'Birbhum',
  'Cooch Behar',
  'Dakshin Dinajpur',
  'Darjeeling',
  'Hooghly',
  'Howrah',
  'Jalpaiguri',
  'Jhargram',
  'Kalimpong',
  'Kolkata',
  'Malda',
  'Murshidabad',
  'Nadia',
  'North 24 Parganas',
  'Paschim Bardhaman',
  'Paschim Medinipur',
  'Purba Bardhaman',
  'Purba Medinipur',
  'Purulia',
  'South 24 Parganas',
  'Uttar Dinajpur',
];

// ── Add external doctor bottom sheet ─────────────────────────────────────────

class _AddExternalDoctorSheet extends ConsumerStatefulWidget {
  const _AddExternalDoctorSheet();

  @override
  ConsumerState<_AddExternalDoctorSheet> createState() =>
      _AddExternalDoctorSheetState();
}

class _AddExternalDoctorSheetState
    extends ConsumerState<_AddExternalDoctorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _specializationController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _saving = false;
  String? _errorMessage;
  String? _areaDistrict;
  String? _meetDrType;

  @override
  void dispose() {
    _nameController.dispose();
    _specializationController.dispose();
    _hospitalController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref.read(externalDoctorsProvider.notifier).add(
            name: _nameController.text,
            specialization: _specializationController.text,
            hospital: _hospitalController.text,
            phone: _phoneController.text,
            email: _emailController.text,
            areaDistrict: _areaDistrict,
            meetDrType: _meetDrType,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = AppError.getMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Add External Doctor',
                  style:
                      AppTheme.headingFont(size: 18, weight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(AppIcons.close_rounded,
                      color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 16),
            NeuTextField(
              controller: _nameController,
              label: 'Name *',
              hint: 'Dr. Full Name',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            NeuTextField(
              controller: _specializationController,
              label: 'Specialization',
              hint: 'e.g. Cardiology, Orthopedics',
            ),
            const SizedBox(height: 12),
            NeuTextField(
              controller: _hospitalController,
              label: 'Hospital / Clinic',
              hint: 'Hospital or clinic name',
            ),
            const SizedBox(height: 12),
            NeuTextField(
              controller: _phoneController,
              label: 'Phone',
              hint: 'Contact number',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            NeuTextField(
              controller: _emailController,
              label: 'Email',
              hint: 'Email address',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _areaDistrict,
              decoration: const InputDecoration(
                labelText: 'Area (District)',
                hintText: 'Select district',
              ),
              items: _westBengalDistricts
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => setState(() => _areaDistrict = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _meetDrType,
              decoration: const InputDecoration(
                labelText: 'Type of Doctor',
                hintText: 'Select doctor type',
              ),
              items: ['Dental', 'ENT', 'General Surgeon', 'GP', 'RMP', 'MDS']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _meetDrType = v),
            ),
            const SizedBox(height: 20),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.errorColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(AppIcons.error_outline_rounded,
                          color: AppTheme.errorColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTheme.bodyFont(
                              size: 13, color: AppTheme.errorColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: NeuButton(
                onPressed: _saving ? null : _save,
                isLoading: _saving,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Edit external doctor bottom sheet ────────────────────────────────────────

class _EditExternalDoctorSheet extends ConsumerStatefulWidget {
  const _EditExternalDoctorSheet({required this.doctor});

  final ExternalDoctor doctor;

  @override
  ConsumerState<_EditExternalDoctorSheet> createState() =>
      _EditExternalDoctorSheetState();
}

class _EditExternalDoctorSheetState
    extends ConsumerState<_EditExternalDoctorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _specializationController;
  late final TextEditingController _hospitalController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  bool _saving = false;
  String? _errorMessage;
  String? _areaDistrict;
  String? _meetDrType;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.doctor.name);
    _specializationController =
        TextEditingController(text: widget.doctor.specialization ?? '');
    _hospitalController =
        TextEditingController(text: widget.doctor.hospital ?? '');
    _phoneController =
        TextEditingController(text: widget.doctor.phone ?? '');
    _emailController =
        TextEditingController(text: widget.doctor.email ?? '');
    _areaDistrict = widget.doctor.areaDistrict;
    _meetDrType = widget.doctor.meetDrType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specializationController.dispose();
    _hospitalController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref.read(externalDoctorsProvider.notifier).updateDoctor(
            id: widget.doctor.id,
            name: _nameController.text,
            specialization: _specializationController.text,
            hospital: _hospitalController.text,
            phone: _phoneController.text,
            email: _emailController.text,
            areaDistrict: _areaDistrict,
            meetDrType: _meetDrType,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = AppError.getMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Edit External Doctor',
                  style:
                      AppTheme.headingFont(size: 18, weight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(AppIcons.close_rounded,
                      color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 16),
            NeuTextField(
              controller: _nameController,
              label: 'Name *',
              hint: 'Dr. Full Name',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            NeuTextField(
              controller: _specializationController,
              label: 'Specialization',
              hint: 'e.g. Cardiology, Orthopedics',
            ),
            const SizedBox(height: 12),
            NeuTextField(
              controller: _hospitalController,
              label: 'Hospital / Clinic',
              hint: 'Hospital or clinic name',
            ),
            const SizedBox(height: 12),
            NeuTextField(
              controller: _phoneController,
              label: 'Phone',
              hint: 'Contact number',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            NeuTextField(
              controller: _emailController,
              label: 'Email',
              hint: 'Email address',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _areaDistrict,
              decoration: const InputDecoration(
                labelText: 'Area (District)',
                hintText: 'Select district',
              ),
              items: _westBengalDistricts
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => setState(() => _areaDistrict = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _meetDrType,
              decoration: const InputDecoration(
                labelText: 'Type of Doctor',
                hintText: 'Select doctor type',
              ),
              items: ['Dental', 'ENT', 'General Surgeon', 'GP', 'RMP', 'MDS']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _meetDrType = v),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.errorColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(AppIcons.error_outline_rounded,
                        color: AppTheme.errorColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTheme.bodyFont(
                            size: 13, color: AppTheme.errorColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: NeuButton(
                onPressed: _saving ? null : _save,
                isLoading: _saving,
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Staff activity drill-in sheet ────────────────────────────────────────────

class _StaffActivitySheet extends ConsumerWidget {
  const _StaffActivitySheet({
    required this.member,
    required this.selectedDate,
  });

  final DoctorModel member;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(staffActivityProvider(selectedDate));
    final isDoctor = member.role == UserRole.doctor.databaseValue;
    final badgeColor =
        isDoctor ? AppTheme.doctorAccent : AppTheme.assistantAccent;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = selectedDate == today;
    final dateLabel =
        isToday ? 'Today' : DateFormat('EEE, MMM d, yyyy').format(selectedDate);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // ── Handle ──
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(AppIcons.person_rounded,
                          color: badgeColor, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          member.fullName,
                          style: AppTheme.bodyFont(
                              size: 16, weight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(AppIcons.calendar_today_rounded,
                                size: 10, color: AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              dateLabel,
                              style: AppTheme.bodyFont(
                                  size: 11,
                                  color: AppTheme.textMuted,
                                  weight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.close_rounded,
                        size: 18, color: AppTheme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── Body ──
            Expanded(
              child: activityAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryTeal)),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load activity',
                      style: AppTheme.bodyFont(
                          size: 13, color: AppTheme.textMuted),
                    ),
                  ),
                ),
                data: (map) {
                  final activity = map[member.id];
                  return _ActivitySheetBody(
                    isDoctor: isDoctor,
                    activity: activity,
                    scrollController: scrollController,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ActivitySheetBody extends StatelessWidget {
  const _ActivitySheetBody({
    required this.isDoctor,
    required this.activity,
    required this.scrollController,
  });

  final bool isDoctor;
  final StaffActivity? activity;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    if (a == null || a.isEmpty) {
      return _SheetEmptyState(
        icon: AppIcons.history_toggle_off_rounded,
        message: isDoctor
            ? 'No clinical activity for this date.'
            : 'No field activity for this date.',
      );
    }

    final tabs = <Tab>[];
    final views = <Widget>[];

    if (isDoctor) {
      if (a.drVisits.isNotEmpty) {
        tabs.add(Tab(text: 'Visits · ${a.drVisits.length}'));
        views.add(_DrVisitsList(
            items: a.drVisits, scrollController: scrollController));
      }
      if (a.followupsAssigned.isNotEmpty) {
        tabs.add(Tab(text: 'Follow-ups · ${a.followupsAssigned.length}'));
        views.add(_FollowupList(
            items: a.followupsAssigned,
            scrollController: scrollController,
            timeKey: 'created_at',
            timeLabel: 'Assigned'));
      }
    } else {
      if (a.outsideVisits.isNotEmpty) {
        tabs.add(Tab(text: 'Outside · ${a.outsideVisits.length}'));
        views.add(_OutsideVisitsList(
            items: a.outsideVisits, scrollController: scrollController));
      }
      if (a.followupsCompleted.isNotEmpty) {
        tabs.add(Tab(text: 'Completed · ${a.followupsCompleted.length}'));
        views.add(_FollowupList(
            items: a.followupsCompleted,
            scrollController: scrollController,
            timeKey: 'completed_at',
            timeLabel: 'Completed'));
      }
    }

    // Single tab? Skip the tab bar.
    if (tabs.length == 1) return views.first;

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          TabBar(
            tabs: tabs,
            labelColor: AppTheme.primaryTeal,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.primaryTeal,
            indicatorWeight: 2.5,
            isScrollable: tabs.length > 2,
            tabAlignment:
                tabs.length > 2 ? TabAlignment.start : TabAlignment.fill,
            labelStyle: AppTheme.bodyFont(size: 12, weight: FontWeight.w700),
            unselectedLabelStyle: AppTheme.bodyFont(size: 12),
          ),
          Expanded(child: TabBarView(children: views)),
        ],
      ),
    );
  }
}

class _DrVisitsList extends StatelessWidget {
  const _DrVisitsList(
      {required this.items, required this.scrollController});

  final List<Map<String, dynamic>> items;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final v = items[i];
        final patient = v['patients'] as Map<String, dynamic>?;
        final patientName =
            (patient?['full_name'] as String?) ?? 'Unknown patient';
        final time = _formatTime(v['visit_date']);
        final status =
            (v['followup_status'] as String?) ?? v['status'] as String? ?? '';
        return _ActivityListTile(
          title: patientName,
          subtitleIcon: AppIcons.access_time_rounded,
          subtitleText: time,
          statusLabel: status,
          accent: AppTheme.doctorAccent,
          icon: AppIcons.medical_services_rounded,
          onTap: () {
            Navigator.of(context).pop();
            context.push('/dr-visits/${v['id']}');
          },
        );
      },
    );
  }
}

class _OutsideVisitsList extends StatelessWidget {
  const _OutsideVisitsList(
      {required this.items, required this.scrollController});

  final List<Map<String, dynamic>> items;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final v = items[i];
        final patient = v['patients'] as Map<String, dynamic>?;
        final patientName =
            (patient?['full_name'] as String?) ?? 'Unknown patient';
        final extName = (v['ext_doctor_name'] as String?) ?? '';
        final extHosp = (v['ext_doctor_hospital'] as String?) ?? '';
        final subtitle = [
          if (extName.isNotEmpty) extName,
          if (extHosp.isNotEmpty) extHosp,
        ].join(' · ');
        return _ActivityListTile(
          title: patientName,
          subtitleIcon: AppIcons.local_hospital_rounded,
          subtitleText: subtitle.isEmpty ? 'External visit' : subtitle,
          statusLabel: v['status'] as String? ?? '',
          accent: AppTheme.assistantAccent,
          icon: AppIcons.local_hospital_rounded,
          onTap: () {
            Navigator.of(context).pop();
            context.push('/agent-visits/edit/${v['id']}');
          },
        );
      },
    );
  }
}

class _FollowupList extends StatelessWidget {
  const _FollowupList({
    required this.items,
    required this.scrollController,
    required this.timeKey,
    required this.timeLabel,
  });

  final List<Map<String, dynamic>> items;
  final ScrollController scrollController;
  final String timeKey;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final t = items[i];
        final patient = t['patients'] as Map<String, dynamic>?;
        final patientName =
            (patient?['full_name'] as String?) ?? 'Unknown patient';
        final time = _formatTime(t[timeKey]);
        return _ActivityListTile(
          title: patientName,
          subtitleIcon: AppIcons.access_time_rounded,
          subtitleText: '$timeLabel · $time',
          statusLabel: t['status'] as String? ?? '',
          accent: AppTheme.primaryTeal,
          icon: AppIcons.add_task_rounded,
          onTap: () {
            Navigator.of(context).pop();
            context.push('/followups/review/${t['id']}');
          },
        );
      },
    );
  }
}

class _ActivityListTile extends StatelessWidget {
  const _ActivityListTile({
    required this.title,
    required this.subtitleIcon,
    required this.subtitleText,
    required this.statusLabel,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData subtitleIcon;
  final String subtitleText;
  final String statusLabel;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.bgColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: AppTheme.surfaceWhite,
                offset: Offset(-1.5, -1.5),
                blurRadius: 4,
              ),
              BoxShadow(
                color: AppTheme.neuShadowDark,
                offset: Offset(1.5, 1.5),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(icon, size: 16, color: accent),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTheme.bodyFont(
                          size: 13, weight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitleText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(subtitleIcon,
                              size: 10, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              subtitleText,
                              style: AppTheme.bodyFont(
                                  size: 11, color: AppTheme.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (statusLabel.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(statusLabel).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel.toUpperCase(),
                    style: AppTheme.bodyFont(
                        size: 9,
                        weight: FontWeight.w800,
                        color: _statusColor(statusLabel)),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(AppIcons.arrow_forward_ios_rounded,
                  size: 10, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
        return AppTheme.successColor;
      case 'pending':
        return AppTheme.warningColor;
      case 'recorded':
      case 'active':
        return AppTheme.primaryTeal;
      case 'rejected':
      case 'cancelled':
        return AppTheme.errorColor;
      default:
        return AppTheme.textMuted;
    }
  }
}

class _SheetEmptyState extends StatelessWidget {
  const _SheetEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 44, color: AppTheme.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.bodyFont(size: 13, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(dynamic value) {
  if (value == null) return '--:--';
  final dt = DateTime.tryParse(value.toString());
  if (dt == null) return value.toString();
  return DateFormat.jm().format(dt.toLocal());
}

// ── Shared helper widgets ─────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _PlaceholderView extends StatelessWidget {
  const _PlaceholderView({
    required this.icon,
    required this.message,
    this.iconColor,
  });

  final IconData icon;
  final String message;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 48,
                color: iconColor ?? AppTheme.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.bodyFont(size: 14, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
