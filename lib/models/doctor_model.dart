import 'package:flutter/foundation.dart';

@immutable
class DoctorModel {
  final String id;
  final String fullName;
  final String? specialization;
  final String? email;
  final String role;
  final String? approvalStatus;
  final DateTime? createdAt;

  const DoctorModel({
    required this.id,
    required this.fullName,
    this.specialization,
    this.email,
    required this.role,
    this.approvalStatus,
    this.createdAt,
  });

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      id: (json['id'] ?? '') as String,
      fullName: (json['full_name'] ?? 'Unknown') as String,
      specialization: json['specialization'] as String?,
      email: json['email'] as String?,
      role: (json['role'] ?? 'assistant') as String,
      approvalStatus: json['approval_status'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
