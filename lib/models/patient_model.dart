import 'package:flutter/foundation.dart';
import 'package:mediflow/core/parse_utils.dart';

@immutable
class PatientModel {
  const PatientModel({
    required this.id,
    required this.fullName,
    required this.createdById,
    this.phone,
    this.email,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.symptoms,
    this.areaAffected,
    this.existingConditions,
    this.currentMedications,
    this.allergies,
    this.addictions,
    this.healthScheme,
    this.address,
    this.referredBy,
    this.investigationPlace,
    this.investigationStatus = const <String, dynamic>{},
    this.staffComments,
    this.createdAt,
    this.lastUpdatedAt,
    this.lastVisitDate,
    required this.serviceStatus,
    required this.isHighPriority,
    this.lastUpdatedBy,
    this.visitType,
    this.assignedDoctorId,
  });

  final String id;
  final String fullName;
  final String createdById;
  final String? phone;
  final String? email;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodGroup;
  final String? symptoms;
  final String? areaAffected;
  final String? existingConditions;
  final String? currentMedications;
  final String? allergies;
  final String? addictions;
  final String? healthScheme;
  final String? address;
  final String? referredBy;
  final String? investigationPlace;
  final Map<String, dynamic> investigationStatus;
  final String? staffComments;
  final DateTime? createdAt;
  final DateTime? lastUpdatedAt;
  final DateTime? lastVisitDate;
  final String serviceStatus;
  final bool isHighPriority;
  final String? lastUpdatedBy;
  final String? visitType;
  final String? assignedDoctorId;

  String get shortId {
    if (id.length <= 8) {
      return id;
    }
    return id.substring(0, 8);
  }

  factory PatientModel.fromJson(Map<String, dynamic> map) {
    final rawStatus =
        (map['service_status'] ?? map['status'] ?? 'Test Pending').toString();
    final normalizedStatus = _normalizeServiceStatus(rawStatus);
    final createdById =
        parseDbString(map['created_by_id'] ?? map['uploaded_by_id']);
    final model = PatientModel(
      id: parseDbString(map['id']),
      fullName: parseDbString(map['full_name'] ?? map['name'], 'Unknown Patient'),
      createdById: createdById,
      phone: _nullableString(map['phone']),
      email: _nullableString(map['email']),
      dateOfBirth: parseDbDate(map['date_of_birth']),
      gender: _nullableString(map['gender']),
      bloodGroup: _nullableString(map['blood_group']),
      symptoms: _nullableString(map['symptoms']),
      areaAffected: _nullableString(map['area_affected']),
      existingConditions: _nullableString(map['existing_conditions']),
      currentMedications: _nullableString(map['current_medications']),
      allergies: _nullableString(map['allergies']),
      addictions: _nullableString(map['addictions']),
      healthScheme: _nullableString(map['health_scheme']),
      address: _nullableString(map['address']),
      referredBy: _nullableString(map['referred_by']),
      investigationPlace: _nullableString(map['investigation_place']),
      investigationStatus: parseDbMap(map['investigation_status']) ?? const {},
      staffComments: _nullableString(map['staff_comments']),
      createdAt: parseDbDate(map['created_at']),
      lastUpdatedAt: parseDbDate(map['last_updated_at']),
      lastVisitDate: parseDbDate(map['last_visit_at'] ?? map['last_visit_date']),
      serviceStatus: normalizedStatus,
      isHighPriority:
          (map['is_high_priority'] ?? map['is_priority'] ?? map['high_priority']) ==
              true,
      lastUpdatedBy:
          (map['last_updated_by'] ?? map['updated_by_name'])?.toString(),
      visitType: _nullableString(map['visit_type']),
      assignedDoctorId: _nullableString(map['assigned_doctor_id'] ?? map['doctor_id']),
    );
    model.validate();
    return model;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'created_by_id': createdById,
      'phone': phone,
      'email': email,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'blood_group': bloodGroup,
      'symptoms': symptoms,
      'area_affected': areaAffected,
      'existing_conditions': existingConditions,
      'current_medications': currentMedications,
      'allergies': allergies,
      'addictions': addictions,
      'health_scheme': healthScheme,
      'address': address,
      'referred_by': referredBy,
      'investigation_place': investigationPlace,
      'investigation_status': investigationStatus,
      'staff_comments': staffComments,
      'created_at': createdAt?.toIso8601String(),
      'last_updated_at': lastUpdatedAt?.toIso8601String(),
      'service_status': serviceStatus,
      'is_high_priority': isHighPriority,
      'last_updated_by': lastUpdatedBy,
      'visit_type': visitType,
      'assigned_doctor_id': assignedDoctorId,
    };
  }

  void validate() {
    assert(id.isNotEmpty, 'PatientModel.id must not be empty');
    assert(fullName.trim().isNotEmpty, 'PatientModel.fullName must not be empty');
    assert(createdById.isNotEmpty, 'PatientModel.createdById must not be empty');
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String _normalizeServiceStatus(String value) {
    switch (value.toLowerCase().trim()) {
      case 'all':
        return 'All';
      case 'test done':
      case 'done':
      case 'completed':
        return 'Test Done';
      case 'ot scheduled':
      case 'ot':
        return 'OT Scheduled';
      default:
        return 'Test Pending';
    }
  }
}
