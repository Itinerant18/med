// lib/features/profile/change_password_sheet.dart
import 'package:flutter/material.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _saving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _passwordValidator(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'At least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Include an uppercase letter';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Include a number';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final newPassword = _newCtrl.text;
    final confirm = _confirmCtrl.text;
    if (newPassword != confirm) {
      AppSnackbar.showError(
          context, 'New password and confirmation do not match.');
      return;
    }

    setState(() => _saving = true);
    try {
      final supabase = Supabase.instance.client;
      final email = supabase.auth.currentUser?.email;

      // Verify current password by re-authenticating. If the account has no
      // email/password identity (e.g. phone-only sign in), skip verification.
      if (email != null && _currentCtrl.text.isNotEmpty) {
        try {
          await supabase.auth.signInWithPassword(
            email: email,
            password: _currentCtrl.text,
          );
        } on AuthException {
          if (!mounted) return;
          AppSnackbar.showError(context, 'Current password is incorrect.');
          setState(() => _saving = false);
          return;
        }
      }

      await supabase.auth.updateUser(UserAttributes(password: newPassword));

      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'Password updated successfully.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, AppError.getMessage(e));
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
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Change Password',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your password must be at least 8 characters and include a number and an uppercase letter.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 20),
              NeuTextField(
                controller: _currentCtrl,
                label: 'Current password',
                obscureText: _obscureCurrent,
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent
                      ? AppIcons.visibility_outlined
                      : AppIcons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter current password' : null,
              ),
              const SizedBox(height: 12),
              NeuTextField(
                controller: _newCtrl,
                label: 'New password',
                obscureText: _obscureNew,
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew
                      ? AppIcons.visibility_outlined
                      : AppIcons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
                validator: _passwordValidator,
              ),
              const SizedBox(height: 12),
              NeuTextField(
                controller: _confirmCtrl,
                label: 'Confirm new password',
                obscureText: _obscureNew,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Confirm your new password';
                  }
                  if (v != _newCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              NeuButton(
                onPressed: _saving ? null : _submit,
                isLoading: _saving,
                child: const Text(
                  'UPDATE PASSWORD',
                  style: TextStyle(
                    color: AppTheme.primaryForeground,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
