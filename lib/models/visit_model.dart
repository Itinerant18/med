import 'package:flutter/foundation.dart';
import 'package:mediflow/core/parse_utils.dart';

@immutable
class DrVisit {
  final String id;
  final String? patientId;
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
  final bool isExternalDoctor;
  final String? extDoctorName;
  final String? extDoctorSpecialization;
  final String? extDoctorHospital;
  final String? extDoctorPhone;
  final String? leadPatientName;
  final String? leadPatientPhone;
  final String? leadPatientAddress;
  final String? leadNotes;
  final String leadStatus;
  final String? convertedPatientId;
  final List<Map<String, dynamic>> contactAttempts;

  // Joined fields
  final String? patientName;
  final String? agentName;

  const DrVisit({
    required this.id,
    this.patientId,
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
    this.isExternalDoctor = false,
    this.extDoctorName,
    this.extDoctorSpecialization,
    this.extDoctorHospital,
    this.extDoctorPhone,
    this.leadPatientName,
    this.leadPatientPhone,
    this.leadPatientAddress,
    this.leadNotes,
    this.leadStatus = 'new_lead',
    this.convertedPatientId,
    this.contactAttempts = const [],
    this.patientName,
    this.agentName,
  });

  factory DrVisit.fromJson(Map<String, dynamic> json) {
    final patients = parseDbMap(json['patients']);
    final agent = parseDbMap(json['agent']);
    return DrVisit(
      id: parseDbString(json['id']),
      patientId: json['patient_id']?.toString(),
      doctorId: parseDbString(json['doctor_id']),
      assignedAgentId: json['assigned_agent_id']?.toString(),
      visitNotes: json['visit_notes']?.toString(),
      diagnosis: json['diagnosis']?.toString(),
      // visit_date / created_at are required, but the row could be malformed
      // in storage. Fall back to "now" so we never crash a list render.
      visitDate: parseDbDateOr(json['visit_date'], DateTime.now()),
      followupDate: parseDbDate(json['followup_date']),
      followupNotes: json['followup_notes']?.toString(),
      followupStatus: parseDbString(json['followup_status'], 'pending'),
      status: parseDbString(json['status'], 'active'),
      createdById: json['created_by_id']?.toString(),
      lastUpdatedBy: json['last_updated_by']?.toString(),
      lastUpdatedAt: parseDbDate(json['last_updated_at']),
      createdAt: parseDbDateOr(json['created_at'], DateTime.now()),
      isExternalDoctor: json['is_external_doctor'] == true,
      extDoctorName: json['ext_doctor_name']?.toString(),
      extDoctorSpecialization: json['ext_doctor_specialization']?.toString(),
      extDoctorHospital: json['ext_doctor_hospital']?.toString(),
      extDoctorPhone: json['ext_doctor_phone']?.toString(),
      leadPatientName: json['lead_patient_name']?.toString(),
      leadPatientPhone: json['lead_patient_phone']?.toString(),
      leadPatientAddress: json['lead_patient_address']?.toString(),
      leadNotes: json['lead_notes']?.toString(),
      leadStatus: parseDbString(json['lead_status'], 'new_lead'),
      convertedPatientId: json['converted_patient_id']?.toString(),
      contactAttempts: ((json['contact_attempts'] as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      patientName: patients?['full_name']?.toString(),
      agentName: agent?['full_name']?.toString(),
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
      'is_external_doctor': isExternalDoctor,
      'ext_doctor_name': extDoctorName,
      'ext_doctor_specialization': extDoctorSpecialization,
      'ext_doctor_hospital': extDoctorHospital,
      'ext_doctor_phone': extDoctorPhone,
      'lead_patient_name': leadPatientName,
      'lead_patient_phone': leadPatientPhone,
      'lead_patient_address': leadPatientAddress,
      'lead_notes': leadNotes,
      'lead_status': leadStatus,
      'converted_patient_id': convertedPatientId,
      'contact_attempts': contactAttempts,
    };
  }
}
