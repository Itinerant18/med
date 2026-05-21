import 'package:flutter/foundation.dart';
import 'package:mediflow/core/parse_utils.dart';

@immutable
class DoctorModel {
  final String id;
  final String fullName;
  final String? specialization;
  final String? email;
  final String? phone;
  final String role;
  final String? approvalStatus;
  final DateTime? createdAt;

  const DoctorModel({
    required this.id,
    required this.fullName,
    this.specialization,
    this.email,
    this.phone,
    required this.role,
    this.approvalStatus,
    this.createdAt,
  });

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      id: parseDbString(json['id']),
      fullName: parseDbString(json['full_name'], 'Unknown'),
      specialization: json['specialization']?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      role: parseDbString(json['role'], 'assistant'),
      approvalStatus: json['approval_status']?.toString(),
      createdAt: parseDbDate(json['created_at']),
    );
  }
}
