// lib/core/role_provider.dart 
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:mediflow/features/auth/auth_provider.dart'; 
import 'package:mediflow/models/user_role.dart'; 
 
final isHeadDoctorProvider = Provider<bool>((ref) { 
  return ref.watch(authNotifierProvider).value?.role == UserRole.headDoctor; 
}); 
 
// Any doctor role (head_doctor or doctor) can access admin-level patient data 
final isAdminProvider = Provider<bool>((ref) { 
  final role = ref.watch(authNotifierProvider).value?.role ?? UserRole.assistant; 
  return role.isAdmin; 
}); 
 
final isAgentProvider = Provider<bool>((ref) { 
  return ref.watch(authNotifierProvider).value?.role == UserRole.assistant; 
}); 
