import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/app_snackbar.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLoginTap() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await ref.read(authNotifierProvider.notifier).signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_hospital_rounded, size: 64, color: Color(0xFF1A6B5A)),
                const SizedBox(height: 10),
                const Text('MediFlow', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Color(0xFF1A6B5A))),
                const SizedBox(height: 24),
                NeuCard(
                  borderRadius: 22,
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          NeuTextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            label: 'Email Address',
                            hint: 'doctor@mediflow.com',
                            validator: (value) => (value == null || !value.contains('@')) ? 'Enter a valid email' : null,
                          ),
                          const SizedBox(height: 16),
                          NeuTextField(
                            controller: _passwordController,
                            obscureText: true,
                            label: 'Password',
                            hint: '********',
                            validator: (value) => (value == null || value.isEmpty) ? 'Password is required' : null,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: NeuButton(
                              onPressed: isLoading ? null : _onLoginTap,
                              isLoading: isLoading,
                              child: const Text('Login', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => context.push('/register'),
                            child: const Text('New Doctor? Register Here'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
