import 'package:flutter/foundation.dart';
import 'package:mediflow/models/user_role.dart';

@immutable
class DoctorModel {
  final String id;
  final String fullName;
  final String? specialization;
  final String email;
  final UserRole role;

  const DoctorModel({
    required this.id,
    required this.fullName,
    this.specialization,
    required this.email,
    required this.role,
  });

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      id: json['id'],
      fullName: json['full_name'],
      specialization: json['specialization'],
      email: json['email'],
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.doctor,
      ),
    );
  }
}
