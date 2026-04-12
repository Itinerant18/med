import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/models/user_role.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _specializationController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  UserRole _selectedRole = UserRole.doctor;

  @override
  void dispose() {
    _fullNameController.dispose();
    _specializationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onCreateAccountTap() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await ref.read(authNotifierProvider.notifier).signUp(
            fullName: _fullNameController.text.trim(),
            specialization: _specializationController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            role: _selectedRole,
          );

      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'Account created successfully. Please log in.');
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, AppError.getMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authNotifierProvider);
    final isLoading = authAsync.isLoading;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop())),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: NeuCard(
            borderRadius: 22,
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Text('Create MediFlow Account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A6B5A))),
                    const SizedBox(height: 24),
                    NeuTextField(controller: _fullNameController, label: 'Full Name'),
                    const SizedBox(height: 12),
                    NeuTextField(controller: _specializationController, label: 'Specialization'),
                    const SizedBox(height: 12),
                    NeuTextField(controller: _emailController, label: 'Email Address'),
                    const SizedBox(height: 12),
                    NeuTextField(controller: _passwordController, obscureText: true, label: 'Password'),
                    const SizedBox(height: 12),
                    NeuTextField(controller: _confirmPasswordController, obscureText: true, label: 'Confirm Password'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<UserRole>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      items: UserRole.values.map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Text(role.label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedRole = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: NeuButton(
                        onPressed: isLoading ? null : _onCreateAccountTap,
                        isLoading: isLoading,
                        child: const Text('Create Account'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
