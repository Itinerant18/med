import 'package:flutter/foundation.dart';

// TODO: Define the patient domain model with serialization helpers.
@immutable
class PatientModel {
  const PatientModel({
    required this.id,
    required this.fullName,
    this.lastVisitDate,
    required this.serviceStatus,
    required this.isHighPriority,
    this.lastUpdatedBy,
    this.visitType,
    this.assignedDoctorId,
  });

  final String id;
  final String fullName;
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

  factory PatientModel.fromMap(Map<String, dynamic> map) {
    final rawDate = map['last_visit_at'] ?? map['last_visit_date'];
    final parsedDate = rawDate is String
        ? DateTime.tryParse(rawDate)
        : rawDate is DateTime
            ? rawDate
            : null;

    final rawStatus =
        (map['service_status'] ?? map['status'] ?? 'Test Pending').toString();
    final normalizedStatus = _normalizeServiceStatus(rawStatus);

    return PatientModel(
      id: (map['id'] ?? '').toString(),
      fullName:
          (map['full_name'] ?? map['name'] ?? 'Unknown Patient').toString(),
      lastVisitDate: parsedDate,
      serviceStatus: normalizedStatus,
      isHighPriority:
          (map['is_priority'] ?? map['high_priority'] ?? false) == true,
      lastUpdatedBy:
          (map['last_updated_by'] ?? map['updated_by_name'])?.toString(),
      visitType: (map['visit_type'])?.toString(),
      assignedDoctorId:
          (map['assigned_doctor_id'] ?? map['doctor_id'])?.toString(),
    );
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
