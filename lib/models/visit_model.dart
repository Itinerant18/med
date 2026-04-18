import 'package:flutter/foundation.dart';

@immutable
class DrVisit {
  final String id;
  final String patientId;
  final String doctorId;
  final String? assignedAgentId;
  final String? visitNotes;
  final String? diagnosis;
  final DateTime visitDate;
  final DateTime? followupDate;
  final String? followupNotes;
  final String followupStatus;
  final String status;
  final String? createdById;
  final String? lastUpdatedBy;
  final DateTime? lastUpdatedAt;
  final DateTime createdAt;

  // Joined fields
  final String? patientName;
  final String? agentName;

  const DrVisit({
    required this.id,
    required this.patientId,
    required this.doctorId,
    this.assignedAgentId,
    this.visitNotes,
    this.diagnosis,
    required this.visitDate,
    this.followupDate,
    this.followupNotes,
    this.followupStatus = 'pending',
    this.status = 'active',
    this.createdById,
    this.lastUpdatedBy,
    this.lastUpdatedAt,
    required this.createdAt,
    this.patientName,
    this.agentName,
  });

  factory DrVisit.fromJson(Map<String, dynamic> json) {
    return DrVisit(
      id: json['id'],
      patientId: json['patient_id'],
      doctorId: json['doctor_id'],
      assignedAgentId: json['assigned_agent_id'],
      visitNotes: json['visit_notes'],
      diagnosis: json['diagnosis'],
      visitDate: DateTime.parse(json['visit_date']),
      followupDate: json['followup_date'] != null
          ? DateTime.parse(json['followup_date'])
          : null,
      followupNotes: json['followup_notes'],
      followupStatus: json['followup_status'] ?? 'pending',
      status: json['status'] ?? 'active',
      createdById: json['created_by_id'],
      lastUpdatedBy: json['last_updated_by'],
      lastUpdatedAt: json['last_updated_at'] != null
          ? DateTime.parse(json['last_updated_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      patientName: json['patients']?['full_name'],
      agentName: json['agent']?['full_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'assigned_agent_id': assignedAgentId,
      'visit_notes': visitNotes,
      'diagnosis': diagnosis,
      'visit_date': visitDate.toIso8601String(),
      'followup_date': followupDate?.toIso8601String(),
      'followup_notes': followupNotes,
      'followup_status': followupStatus,
      'status': status,
      'created_by_id': createdById,
      'last_updated_by': lastUpdatedBy,
    };
  }
}
