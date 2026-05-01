// lib/features/profile/assistant_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/features/profile/profile_provider.dart';
import 'package:mediflow/shared/widgets/confirm_dialog.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/features/profile/change_password_dialog.dart';

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
  bool _isLinkingGoogle = false;
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
    final ok = await ConfirmDialog.show(
      context,
      title: 'Logout',
      message: 'Are you sure?',
      confirmLabel: 'Logout',
      isDestructive: true,
    );
    if (ok == true) {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (mounted) context.go('/');
    }
  }

  Future<void> _linkGoogle() async {
    setState(() => _isLinkingGoogle = true);
    try {
      await ref.read(authNotifierProvider.notifier).linkGoogleIdentity();
      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          'Google sign-in linked. You can now use password or Google on this account.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, AppError.getMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isLinkingGoogle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileNotifierProvider);
    final statsAsync = ref.watch(profileStatsProvider);
    final authAsync = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('My Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isEditMode ? AppIcons.close : AppIcons.edit_outlined,
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
                            backgroundColor: AppTheme.assistantAccent,
                            child: Text(initials,
                                style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryForeground)),
                          ),
                          const SizedBox(height: 14),
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          Text(data['specialization'] ?? 'Field Agent',
                              style:
                                  const TextStyle(color: AppTheme.textMuted)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.assistantAccent
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: AppTheme.assistantAccent),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(AppIcons.assignment_ind_outlined,
                                    size: 15, color: AppTheme.assistantAccent),
                                SizedBox(width: 5),
                                Text('Field Agent',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.assistantAccent)),
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
                                      color: AppTheme.sectionLabel,
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
                                    color: AppTheme.neutralDivider),
                                _stat(s['visits'].toString(), 'My Patients'),
                                Container(
                                    height: 36,
                                    width: 1,
                                    color: AppTheme.neutralDivider),
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
                                    color: AppTheme.sectionLabel,
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
                            _infoRow(AppIcons.person_outline, 'Full Name',
                                _nameCtrl.text),
                            _infoRow(AppIcons.phone_outlined, 'Phone',
                                _phoneCtrl.text),
                          ],
                          _infoRow(AppIcons.email_outlined, 'Email',
                              data['email'] ?? '',
                              locked: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    NeuCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(bottom: 14),
                            child: Text('SIGN-IN METHODS',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.sectionLabel,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w600)),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _providerChip(
                                label: 'Password',
                                enabled: authAsync
                                        .valueOrNull?.hasPasswordIdentity ??
                                    false,
                                icon: AppIcons.lock_outline,
                              ),
                              _providerChip(
                                label: 'Google',
                                enabled:
                                    authAsync.valueOrNull?.hasGoogleIdentity ??
                                        false,
                                icon: AppIcons.g_mobiledata_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            authAsync.valueOrNull?.hasGoogleIdentity ?? false
                                ? 'This account is linked for both password and Google sign-in.'
                                : 'Link Google once while signed in, then you can use either password or Google on the same account.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed:
                                  (authAsync.valueOrNull?.hasGoogleIdentity ??
                                              false) ||
                                          _isLinkingGoogle
                                      ? null
                                      : _linkGoogle,
                              icon: _isLinkingGoogle
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(AppIcons.link_rounded),
                              label: Text(
                                authAsync.valueOrNull?.hasGoogleIdentity ??
                                        false
                                    ? 'Google Linked'
                                    : 'Link Google Sign-In',
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFFD1D9E6),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Access Note
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                AppTheme.warningColor.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(AppIcons.info_outline_rounded,
                              color: AppTheme.warningColor, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'As a field agent, you register patients you bring in and manage your assigned tasks. You only see patients you have registered.',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.warningColor),
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
                            leading: const Icon(AppIcons.info_outline,
                                color: AppTheme.primaryTeal, size: 20),
                            title: const Text('About MediFlow'),
                            trailing: const Icon(AppIcons.chevron_right,
                                size: 18, color: AppTheme.textMuted),
                            onTap: () => context.push('/about'),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(
                                AppIcons.notifications_none_rounded,
                                color: AppTheme.secondary,
                                size: 20),
                            title: const Text('Notification Preferences'),
                            trailing: const Icon(AppIcons.chevron_right,
                                size: 18, color: AppTheme.textMuted),
                            onTap: () =>
                                context.push('/notification-preferences'),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(AppIcons.lock_outline,
                                color: AppTheme.primaryTeal, size: 20),
                            title: const Text('Change Password'),
                            trailing: const Icon(AppIcons.chevron_right,
                                size: 18, color: AppTheme.textMuted),
                            onTap: () => ChangePasswordDialog.show(context),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(AppIcons.logout,
                                color: AppTheme.errorColor, size: 20),
                            title: const Text('Logout',
                                style: TextStyle(
                                    color: AppTheme.errorColor,
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
                        color: AppTheme.assistantAccent,
                        child: const Text('SAVE CHANGES',
                            style: TextStyle(
                                color: AppTheme.primaryForeground,
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
                  color: AppTheme.assistantAccent)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ],
      );

  Widget _providerChip({
    required String label,
    required bool enabled,
    required IconData icon,
  }) {
    final color = enabled ? AppTheme.primaryTeal : AppTheme.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: enabled
            ? AppTheme.primaryTeal.withValues(alpha: 0.08)
            : AppTheme.neutralLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: enabled ? AppTheme.primaryTeal : AppTheme.neutralDivider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

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
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textMuted)),
                Text(value.isEmpty ? 'Not set' : value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            )),
            if (locked)
              const Icon(AppIcons.lock_outline,
                  size: 14, color: AppTheme.textMuted),
          ],
        ),
      );
}
