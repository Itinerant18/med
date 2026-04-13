import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/models/user_role.dart';

final currentRoleProvider = Provider<UserRole>((ref) {
  return ref.watch(authNotifierProvider).value?.role ?? UserRole.doctor;
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentRoleProvider).isAdmin;
});
