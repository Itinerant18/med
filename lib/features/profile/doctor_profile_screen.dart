// lib/features/profile/doctor_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/features/profile/profile_provider.dart';
import 'package:mediflow/features/auth/login_screen.dart';
import 'package:mediflow/features/approval/pending_approvals_screen.dart';
import 'package:mediflow/core/role_provider.dart';

class DoctorProfileScreen extends ConsumerStatefulWidget {
  const DoctorProfileScreen({super.key});
  @override
  ConsumerState<DoctorProfileScreen> createState() =>
      _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends ConsumerState<DoctorProfileScreen> {
  bool _isEditMode = false;
  bool _hasPopulated = false;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl = TextEditingController();
  late final TextEditingController _specCtrl = TextEditingController();
  late final TextEditingController _phoneCtrl = TextEditingController();
  late final TextEditingController _clinicNameCtrl = TextEditingController();
  late final TextEditingController _clinicAddrCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _specCtrl.dispose();
    _phoneCtrl.dispose();
    _clinicNameCtrl.dispose();
    _clinicAddrCtrl.dispose();
    super.dispose();
  }

  void _populate(Map<String, dynamic> d) {
    _nameCtrl.text = d['full_name'] ?? '';
    _specCtrl.text = d['specialization'] ?? '';
    _phoneCtrl.text = d['phone'] ?? '';
    _clinicNameCtrl.text = d['clinic_name'] ?? '';
    _clinicAddrCtrl.text = d['clinic_address'] ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(profileNotifierProvider.notifier).updateProfile({
      'full_name': _nameCtrl.text.trim(),
      'specialization': _specCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'clinic_name': _clinicNameCtrl.text.trim(),
      'clinic_address': _clinicAddrCtrl.text.trim(),
    });
    if (mounted) {
      AppSnackbar.showSuccess(context, 'Profile updated');
      setState(() => _isEditMode = false);
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileNotifierProvider);
    final statsAsync = ref.watch(profileStatsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Doctor Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isEditMode ? Icons.close : Icons.edit_outlined,
                color: AppTheme.primaryTeal),
            onPressed: () {
              if (!_isEditMode) _populate(profileAsync.value ?? {});
              setState(() => _isEditMode = !_isEditMode);
            },
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(AppError.getMessage(e))),
        data: (data) {
          if (!_hasPopulated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _populate(data);
                setState(() => _hasPopulated = true);
              }
            });
          }
          final name = data['full_name'] ?? 'Doctor';
          final initials = name
              .trim()
              .split(' ')
              .take(2)
              .map((e) => e[0])
              .join()
              .toUpperCase();
          return RefreshIndicator(
            color: AppTheme.primaryTeal,
            onRefresh: () async {
              ref.invalidate(profileNotifierProvider);
              ref.invalidate(profileStatsProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Avatar + Role Badge
                    NeuCard(
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 52,
                                backgroundColor: AppTheme.primaryTeal,
                                child: Text(initials,
                                    style: const TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1A6B5A),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.verified,
                                    size: 18, color: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          Text(data['specialization'] ?? 'Specialist',
                              style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primaryTeal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.primaryTeal),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.admin_panel_settings,
                                    size: 15, color: AppTheme.primaryTeal),
                                const SizedBox(width: 5),
                                Text(
                                    ref.watch(isHeadDoctorProvider)
                                        ? 'Head Doctor · Super Admin'
                                        : 'Doctor',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryTeal)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Stats
                    statsAsync.when(
                      data: (s) => NeuCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _stat(s['patients'].toString(), 'Patients'),
                            _divider(),
                            _stat(s['visits'].toString(), 'Visits'),
                            _divider(),
                            _stat(s['days'].toString(), 'Days Active'),
                          ],
                        ),
                      ),
                      loading: () =>
                          const NeuCard(child: LinearProgressIndicator()),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 20),

                    // Personal Info
                    NeuCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader('Personal Information'),
                          if (_isEditMode) ...[
                            NeuTextField(
                                controller: _nameCtrl,
                                label: 'Full Name',
                                validator: (v) =>
                                    v == null || v.isEmpty ? 'Required' : null),
                            const SizedBox(height: 12),
                            NeuTextField(
                                controller: _specCtrl, label: 'Specialization'),
                            const SizedBox(height: 12),
                            NeuTextField(
                                controller: _phoneCtrl,
                                label: 'Phone',
                                keyboardType: TextInputType.phone),
                          ] else ...[
                            _infoRow(Icons.person_outline, 'Full Name',
                                _nameCtrl.text),
                            _infoRow(Icons.medical_services_outlined,
                                'Specialization', _specCtrl.text),
                            _infoRow(
                                Icons.phone_outlined, 'Phone', _phoneCtrl.text),
                          ],
                          _infoRow(Icons.email_outlined, 'Email',
                              data['email'] ?? '',
                              locked: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Clinic Info
                    NeuCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader('Clinic Details'),
                          if (_isEditMode) ...[
                            NeuTextField(
                                controller: _clinicNameCtrl,
                                label: 'Clinic Name'),
                            const SizedBox(height: 12),
                            NeuTextField(
                                controller: _clinicAddrCtrl,
                                label: 'Clinic Address',
                                maxLines: 2),
                          ] else ...[
                            _infoRow(Icons.local_hospital_outlined, 'Clinic',
                                _clinicNameCtrl.text),
                            _infoRow(Icons.location_on_outlined, 'Address',
                                _clinicAddrCtrl.text),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Admin Functions
                    NeuCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          if (ref.watch(isHeadDoctorProvider)) ...[
                            _tile(Icons.how_to_reg_rounded, 'Pending Approvals',
                                AppTheme.primaryTeal, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const PendingApprovalsScreen()),
                              );
                            }),
                            const Divider(height: 1),
                          ],
                          _tile(Icons.bar_chart_rounded, 'Analytics Dashboard',
                              Colors.deepPurple, () {}),
                          const Divider(height: 1),
                          _tile(Icons.people_alt_outlined,
                              'Manage Staff Accounts', Colors.orange, () {}),
                          const Divider(height: 1),
                          _tile(Icons.history_rounded, 'Audit Logs',
                              Colors.blueGrey, () {}),
                          const Divider(height: 1),
                          _tile(
                              Icons.info_outline,
                              'About MediFlow',
                              AppTheme.primaryTeal,
                              () => context.push('/about')),
                          const Divider(height: 1),
                          _tile(Icons.lock_outline, 'Change Password',
                              AppTheme.primaryTeal, () {}),
                          const Divider(height: 1),
                          _tile(Icons.logout, 'Logout', Colors.red, _logout),
                        ],
                      ),
                    ),

                    if (_isEditMode) ...[
                      const SizedBox(height: 24),
                      NeuButton(
                        onPressed: profileAsync.isLoading ? null : _save,
                        isLoading: profileAsync.isLoading,
                        color: AppTheme.primaryTeal,
                        child: const Text('SAVE CHANGES',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _stat(String val, String label) => Column(
        children: [
          Text(val,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTeal)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );

  Widget _divider() =>
      Container(height: 36, width: 1, color: Colors.grey.shade300);

  Widget _sectionHeader(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(t.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF718096),
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600)),
      );

  Widget _infoRow(IconData icon, String label, String value,
          {bool locked = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(icon,
                size: 18, color: AppTheme.primaryTeal.withValues(alpha: 0.7)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(value.isEmpty ? 'Not set' : value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            )),
            if (locked)
              const Icon(Icons.lock_outline, size: 14, color: Colors.grey),
          ],
        ),
      );

  Widget _tile(IconData icon, String label, Color color, VoidCallback onTap) =>
      ListTile(
        leading: Icon(icon, color: color, size: 20),
        title: Text(label,
            style: TextStyle(
              color: color == Colors.red ? Colors.red : null,
              fontWeight: color == Colors.red ? FontWeight.bold : null,
            )),
        trailing: Icon(Icons.chevron_right,
            size: 18, color: color == Colors.red ? Colors.red : Colors.grey),
        onTap: onTap,
      );
}
