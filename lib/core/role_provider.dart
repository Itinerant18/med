// lib/core/role_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/models/user_role.dart';

// NOTE: currentRoleProvider is also defined in auth_provider.dart
// Use isAdminProvider directly to avoid confusion

final isAdminProvider = Provider<bool>((ref) {
  final role = ref.watch(authNotifierProvider).value?.role ?? UserRole.doctor;
  return role.isAdmin;
});