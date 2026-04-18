// lib/features/profile/assistant_profile_screen.dart
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

class AssistantProfileScreen extends ConsumerStatefulWidget {
  const AssistantProfileScreen({super.key});
  @override
  ConsumerState<AssistantProfileScreen> createState() =>
      _AssistantProfileScreenState();
}

class _AssistantProfileScreenState
    extends ConsumerState<AssistantProfileScreen> {
  bool _isEditMode = false;
  bool _hasPopulated = false;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl = TextEditingController();
  late final TextEditingController _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _populate(Map<String, dynamic> d) {
    _nameCtrl.text = d['full_name'] ?? '';
    _phoneCtrl.text = d['phone'] ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(profileNotifierProvider.notifier).updateProfile({
      'full_name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
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
        title: const Text('My Profile',
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
          final name = data['full_name'] ?? 'Assistant';
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
                    // Avatar
                    NeuCard(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundColor: Colors.amber.shade700,
                            child: Text(initials,
                                style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ),
                          const SizedBox(height: 14),
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          Text(data['specialization'] ?? 'Clinical Assistant',
                              style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.amber.shade700),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.support_agent_rounded,
                                    size: 15, color: Colors.amber.shade700),
                                const SizedBox(width: 5),
                                Text('Assistant',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // My Activity Stats
                    statsAsync.when(
                      data: (s) => NeuCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(bottom: 14),
                              child: Text('MY ACTIVITY',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF718096),
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.w600)),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _stat(s['patients'].toString(), 'My Patients'),
                                Container(
                                    height: 36,
                                    width: 1,
                                    color: Colors.grey.shade300),
                                _stat(s['visits'].toString(), 'My Visits'),
                                Container(
                                    height: 36,
                                    width: 1,
                                    color: Colors.grey.shade300),
                                _stat(s['days'].toString(), 'Days Active'),
                              ],
                            ),
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
                          const Padding(
                            padding: EdgeInsets.only(bottom: 14),
                            child: Text('PERSONAL INFORMATION',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF718096),
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w600)),
                          ),
                          if (_isEditMode) ...[
                            NeuTextField(
                                controller: _nameCtrl,
                                label: 'Full Name',
                                validator: (v) =>
                                    v == null || v.isEmpty ? 'Required' : null),
                            const SizedBox(height: 12),
                            NeuTextField(
                                controller: _phoneCtrl,
                                label: 'Phone',
                                keyboardType: TextInputType.phone),
                          ] else ...[
                            _infoRow(Icons.person_outline, 'Full Name',
                                _nameCtrl.text),
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

                    // Access Note
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: Colors.amber.shade700, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'As an assistant, you can view and manage only the patients you have registered.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.amber.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Actions
                    NeuCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.info_outline,
                                color: AppTheme.primaryTeal, size: 20),
                            title: const Text('About MediFlow'),
                            trailing: const Icon(Icons.chevron_right,
                                size: 18, color: Colors.grey),
                            onTap: () => context.push('/about'),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.lock_outline,
                                color: AppTheme.primaryTeal, size: 20),
                            title: const Text('Change Password'),
                            trailing: const Icon(Icons.chevron_right,
                                size: 18, color: Colors.grey),
                            onTap: () {},
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.logout,
                                color: Colors.red, size: 20),
                            title: const Text('Logout',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold)),
                            onTap: _logout,
                          ),
                        ],
                      ),
                    ),

                    if (_isEditMode) ...[
                      const SizedBox(height: 24),
                      NeuButton(
                        onPressed: profileAsync.isLoading ? null : _save,
                        isLoading: profileAsync.isLoading,
                        color: Colors.amber.shade700,
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
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade700)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
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
}
