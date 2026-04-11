import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/features/profile/profile_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediflow/features/auth/login_screen.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditMode = false;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _specController;
  late TextEditingController _phoneController;
  late TextEditingController _clinicNameController;
  late TextEditingController _clinicAddrController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _specController = TextEditingController();
    _phoneController = TextEditingController();
    _clinicNameController = TextEditingController();
    _clinicAddrController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specController.dispose();
    _phoneController.dispose();
    _clinicNameController.dispose();
    _clinicAddrController.dispose();
    super.dispose();
  }

  void _populateControllers(Map<String, dynamic> data) {
    _nameController.text = data['full_name'] ?? '';
    _specController.text = data['specialization'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    _clinicNameController.text = data['clinic_name'] ?? '';
    _clinicAddrController.text = data['clinic_address'] ?? '';
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'full_name': _nameController.text.trim(),
      'specialization': _specController.text.trim(),
      'phone': _phoneController.text.trim(),
      'clinic_name': _clinicNameController.text.trim(),
      'clinic_address': _clinicAddrController.text.trim(),
    };

    await ref.read(profileNotifierProvider.notifier).updateProfile(data);

    if (mounted) {
      AppSnackbar.showSuccess(context, 'Profile updated successfully');
      setState(() => _isEditMode = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
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
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(_isEditMode ? Icons.close : Icons.edit_outlined, color: AppTheme.primaryTeal),
            onPressed: () {
              if (!_isEditMode) _populateControllers(profileAsync.value ?? {});
              setState(() => _isEditMode = !_isEditMode);
            },
          ),
        ],
      ),
      body: profileAsync.when(
        data: (data) {
          if (!_isEditMode) _populateControllers(data);
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildAvatarSection(data),
                  const SizedBox(height: 24),
                  _buildPersonalInfoSection(data),
                  const SizedBox(height: 24),
                  _buildClinicInfoSection(),
                  const SizedBox(height: 24),
                  _buildStatsSection(statsAsync),
                  const SizedBox(height: 24),
                  _buildActionsSection(),
                  if (_isEditMode) ...[
                    const SizedBox(height: 32),
                    NeuButton(
                      onPressed: profileAsync.isLoading ? null : _handleSave,
                      isLoading: profileAsync.isLoading,
                      color: AppTheme.primaryTeal,
                      child: const Text('SAVE CHANGES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text(AppError.getMessage(e))),
      ),
    );
  }

  Widget _buildAvatarSection(Map<String, dynamic> data) {
    final name = data['full_name'] ?? 'Doctor';
    final initials = name.split(' ').take(2).map((e) => e[0]).join().toUpperCase();

    return NeuCard(
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: AppTheme.primaryTeal,
            child: Text(initials, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(height: 16),
          Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textColor)),
          Text(data['specialization'] ?? 'Medical Specialist', style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, size: 16, color: Colors.green),
                SizedBox(width: 4),
                Text('Verified Doctor', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection(Map<String, dynamic> data) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Personal Information'),
          if (_isEditMode) ...[
            NeuTextField(controller: _nameController, label: 'Full Name'),
            const SizedBox(height: 16),
            NeuTextField(controller: _specController, label: 'Specialization'),
            const SizedBox(height: 16),
            NeuTextField(controller: _phoneController, label: 'Phone Number', keyboardType: TextInputType.phone),
          ] else ...[
            _buildInfoTile(Icons.person_outline, 'Full Name', _nameController.text),
            _buildInfoTile(Icons.medical_services_outlined, 'Specialization', _specController.text),
            _buildInfoTile(Icons.phone_outlined, 'Phone', _phoneController.text),
          ],
          _buildInfoTile(Icons.email_outlined, 'Email Address', data['email'] ?? '', isLocked: true),
        ],
      ),
    );
  }

  Widget _buildClinicInfoSection() {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Clinic Details'),
          if (_isEditMode) ...[
            NeuTextField(controller: _clinicNameController, label: 'Clinic Name'),
            const SizedBox(height: 16),
            NeuTextField(controller: _clinicAddrController, label: 'Clinic Address', maxLines: 2),
          ] else ...[
            _buildInfoTile(Icons.business_outlined, 'Clinic Name', _clinicNameController.text),
            _buildInfoTile(Icons.location_on_outlined, 'Clinic Address', _clinicAddrController.text),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsSection(AsyncValue<Map<String, int>> statsAsync) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Activity Summary'),
          statsAsync.when(
            data: (stats) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatBox(stats['patients'].toString(), 'Patients'),
                _buildStatBox(stats['visits'].toString(), 'Visits'),
                _buildStatBox(stats['days'].toString(), 'Days Active'),
              ],
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Failed to load stats'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    return NeuCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline, color: AppTheme.primaryTeal),
            title: const Text('About MediFlow'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.push('/about'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: AppTheme.primaryTeal),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              // TODO: Implement change password flow
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: _confirmLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, color: Color(0xFF718096), letterSpacing: 1.2, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value, {bool isLocked = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryTeal.withValues(alpha: 0.7)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(value.isEmpty ? 'Not set' : value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (isLocked) const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildStatBox(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
