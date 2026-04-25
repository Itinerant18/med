// lib/features/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/features/auth/phone_otp_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/models/user_role.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _specializationController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  UserRole _selectedRole = UserRole.doctor;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  bool _phoneVerified = false; // ← NEW: phone OTP state

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _specializationController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── Phone verification ────────────────────────────────────────────────────

  void _openPhoneVerification() {
    final rawPhone = _phoneController.text.trim();

    if (rawPhone.isEmpty) {
      AppSnackbar.showWarning(context, 'Enter your mobile number first');
      return;
    }

    // Build E.164 — default to India (+91) if no country code entered
    final e164 = normalizePhoneNumber(rawPhone);

    if (e164.isEmpty || e164.replaceAll(RegExp(r'\D'), '').length < 10) {
      AppSnackbar.showWarning(context, 'Enter a valid mobile number');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhoneOtpScreen(
          phoneNumber: e164,
          onVerified: () {
            Navigator.of(context).pop(); // close OTP screen
            setState(() => _phoneVerified = true);
            AppSnackbar.showSuccess(context, '✓ Phone number verified');
          },
        ),
      ),
    );
  }

  // ── Registration ──────────────────────────────────────────────────────────

  Future<void> _onCreateAccount() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (!_phoneVerified) {
      AppSnackbar.showWarning(
          context, 'Please verify your phone number before registering');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(authNotifierProvider.notifier).signUp(
            fullName: _fullNameController.text.trim(),
            specialization: _specializationController.text.trim(),
            email: _emailController.text.trim().toLowerCase(),
            password: _passwordController.text,
            phone: _phoneController.text.trim(),
            role: _selectedRole,
          );

      if (!mounted) return;

      final authState = ref.read(authNotifierProvider);
      if (authState.hasError) {
        AppSnackbar.showError(context, AppError.getMessage(authState.error));
      } else if (authState.value == null) {
        _showConfirmationDialog();
      } else {
        AppSnackbar.showSuccess(
            context, 'Account created! Welcome to MediFlow.');
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, AppError.getMessage(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _validateGoogleRegistration() {
    if (_fullNameController.text.trim().length < 2) {
      AppSnackbar.showWarning(context, 'Enter your full name first.');
      return false;
    }
    if (_specializationController.text.trim().isEmpty) {
      AppSnackbar.showWarning(context, 'Enter your specialization first.');
      return false;
    }
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      AppSnackbar.showWarning(context, 'Enter a valid mobile number first.');
      return false;
    }
    if (!_phoneVerified) {
      AppSnackbar.showWarning(
        context,
        'Verify your mobile number before continuing with Google.',
      );
      return false;
    }
    return true;
  }

  Future<void> _onGoogleRegister() async {
    FocusScope.of(context).unfocus();
    if (!_validateGoogleRegistration()) return;

    setState(() => _isSubmitting = true);

    try {
      await ref.read(authNotifierProvider.notifier).signInWithGoogle(
            phone: _phoneController.text.trim(),
            requireExistingAccount: false,
            fullName: _fullNameController.text.trim(),
            specialization: _specializationController.text.trim(),
            role: _selectedRole,
            phoneVerified: true,
          );

      if (!mounted) return;
      AppSnackbar.showSuccess(
        context,
        'Google registration completed. Awaiting head doctor approval.',
      );
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, AppError.getMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(AppIcons.mark_email_read_rounded, color: AppTheme.primaryTeal),
            SizedBox(width: 10),
            Text('Check Your Email'),
          ],
        ),
        content: const Text(
          'A confirmation link has been sent to your email address. '
          'Please verify your email before signing in.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/');
            },
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(AppIcons.arrow_back_ios_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Join MediFlow',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Create your professional account',
                          style: TextStyle(
                            color: AppTheme.textMuted.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Personal Info ──
                  NeuCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle(
                            title: 'Personal Details',
                            icon: AppIcons.person_outline),
                        NeuTextField(
                          controller: _fullNameController,
                          label: 'Full Name',
                          hint: 'Dr. John Smith',
                          textCapitalization: TextCapitalization.words,
                          prefixIcon: const Icon(AppIcons.person_outline,
                              color: AppTheme.primaryTeal, size: 18),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Full name is required';
                            }
                            if (value.trim().length < 2) {
                              return 'Name must be at least 2 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        NeuTextField(
                          controller: _specializationController,
                          label: 'Specialization',
                          hint: 'e.g. Cardiology, General Medicine',
                          textCapitalization: TextCapitalization.words,
                          prefixIcon: const Icon(
                              AppIcons.medical_services_outlined,
                              color: AppTheme.primaryTeal,
                              size: 18),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Specialization is required';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Phone Verification ──
                  NeuCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle(
                            title: 'Mobile Verification',
                            icon: AppIcons.phone_iphone_rounded),

                        // Phone field + verify button row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: NeuTextField(
                                controller: _phoneController,
                                label: 'Mobile Number',
                                hint: '+91 98765 43210',
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.done,
                                prefixIcon: const Icon(AppIcons.phone_rounded,
                                    color: AppTheme.primaryTeal, size: 18),
                                suffixIcon: _phoneVerified
                                    ? const Icon(AppIcons.verified_rounded,
                                        color: Color(0xFF38A169), size: 20)
                                    : null,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Mobile number is required';
                                  }
                                  final digits =
                                      value.replaceAll(RegExp(r'\D'), '');
                                  if (digits.length < 10) {
                                    return 'Enter a valid mobile number';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: NeuButton(
                                onPressed: _phoneVerified
                                    ? null
                                    : _openPhoneVerification,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 16),
                                color: _phoneVerified
                                    ? const Color(0xFF38A169)
                                    : AppTheme.primaryTeal,
                                child: Text(
                                  _phoneVerified ? 'Verified' : 'Send OTP',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Verification status
                        if (_phoneVerified) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(AppIcons.check_circle_rounded,
                                  size: 14, color: Color(0xFF38A169)),
                              const SizedBox(width: 6),
                              Text(
                                'Phone number successfully verified',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Enter your number and tap Send OTP to receive a verification code.',
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Account Info ──
                  NeuCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle(
                            title: 'Account Details',
                            icon: AppIcons.lock_outline),
                        NeuTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          hint: 'doctor@mediflow.com',
                          keyboardType: TextInputType.emailAddress,
                          textCapitalization: TextCapitalization.none,
                          autocorrect: false,
                          enableSuggestions: false,
                          prefixIcon: const Icon(AppIcons.email_outlined,
                              color: AppTheme.primaryTeal, size: 18),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                                .hasMatch(value.trim())) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        NeuTextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          label: 'Password',
                          hint: 'At least 8 characters',
                          prefixIcon: const Icon(AppIcons.lock_outlined,
                              color: AppTheme.primaryTeal, size: 18),
                          textInputAction: TextInputAction.next,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? AppIcons.visibility_outlined
                                  : AppIcons.visibility_off_outlined,
                              color: AppTheme.textMuted,
                              size: 18,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            if (value.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            if (!RegExp(r'[0-9]').hasMatch(value)) {
                              return 'Password must contain at least one number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        NeuTextField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          label: 'Confirm Password',
                          hint: 'Re-enter your password',
                          prefixIcon: const Icon(AppIcons.lock_outlined,
                              color: AppTheme.primaryTeal, size: 18),
                          textInputAction: TextInputAction.done,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? AppIcons.visibility_outlined
                                  : AppIcons.visibility_off_outlined,
                              color: AppTheme.textMuted,
                              size: 18,
                            ),
                            onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Role Selection ──
                  NeuCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle(
                            title: 'Account Role',
                            icon: AppIcons.admin_panel_settings_outlined),
                        const SizedBox(height: 4),
                        _buildRoleSelector(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Register Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: NeuButton(
                      onPressed: _isSubmitting ? null : _onCreateAccount,
                      isLoading: _isSubmitting,
                      child: const Text(
                        'Create Account',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : _onGoogleRegister,
                      icon: const Icon(
                        AppIcons.g_mobiledata_rounded,
                        size: 28,
                        color: AppTheme.textColor,
                      ),
                      label: const Text(
                        'Register with Google',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColor,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD1D9E6)),
                        backgroundColor: AppTheme.bgColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Google registration still requires a verified mobile number and role selection.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Already have account
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style:
                            TextStyle(color: AppTheme.textMuted, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: AppTheme.primaryTeal,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    final registrableRoles = [UserRole.doctor, UserRole.assistant];
    return Row(
      children: registrableRoles.map((role) {
        final isSelected = _selectedRole == role;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: role == registrableRoles.last ? 0 : 12,
            ),
            child: GestureDetector(
              onTap: () => setState(() => _selectedRole = role),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryTeal.withValues(alpha: 0.1)
                      : AppTheme.bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryTeal
                        : const Color(0xFFD1D9E6),
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Icon(
                      role == UserRole.doctor
                          ? AppIcons.medical_services_rounded
                          : AppIcons.support_agent_rounded,
                      color: isSelected
                          ? AppTheme.primaryTeal
                          : AppTheme.textMuted,
                      size: 22,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      role.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppTheme.primaryTeal
                            : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role == UserRole.doctor
                          ? 'Full access'
                          : 'Limited access',
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected
                            ? AppTheme.primaryTeal.withValues(alpha: 0.7)
                            : AppTheme.textMuted.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
