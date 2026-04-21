// lib/models/agent_outside_visit_model.dart
import 'package:flutter/foundation.dart';

@immutable
class AgentOutsideVisit {
  const AgentOutsideVisit({
    required this.id,
    required this.patientId,
    this.followupTaskId,
    required this.agentId,
    required this.extDoctorName,
    this.extDoctorSpecialization,
    this.extDoctorHospital,
    this.extDoctorPhone,
    required this.visitDate,
    this.chiefComplaint,
    this.diagnosis,
    this.prescriptions,
    this.visitNotes,
    this.nextFollowupDate,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    this.patientName,
  });

  final String id;
  final String patientId;
  final String? followupTaskId;
  final String agentId;
  final String extDoctorName;
  final String? extDoctorSpecialization;
  final String? extDoctorHospital;
  final String? extDoctorPhone;
  final DateTime visitDate;
  final String? chiefComplaint;
  final String? diagnosis;
  final String? prescriptions;
  final String? visitNotes;
  final DateTime? nextFollowupDate;
  final String status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  // Joined
  final String? patientName;

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    final s = v.toString();
    if (s.length == 10) {
      final p = s.split('-');
      if (p.length == 3) {
        return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      }
    }
    return DateTime.tryParse(s) ?? DateTime.now();
  }

  factory AgentOutsideVisit.fromJson(Map<String, dynamic> json) {
    return AgentOutsideVisit(
      id: json['id']?.toString() ?? '',
      patientId: json['patient_id']?.toString() ?? '',
      followupTaskId: json['followup_task_id']?.toString(),
      agentId: json['agent_id']?.toString() ?? '',
      extDoctorName: json['ext_doctor_name']?.toString() ?? '',
      extDoctorSpecialization: json['ext_doctor_specialization']?.toString(),
      extDoctorHospital: json['ext_doctor_hospital']?.toString(),
      extDoctorPhone: json['ext_doctor_phone']?.toString(),
      visitDate: _parseDate(json['visit_date']),
      chiefComplaint: json['chief_complaint']?.toString(),
      diagnosis: json['diagnosis']?.toString(),
      prescriptions: json['prescriptions']?.toString(),
      visitNotes: json['visit_notes']?.toString(),
      nextFollowupDate: json['next_followup_date'] != null
          ? _parseDate(json['next_followup_date'])
          : null,
      status: json['status']?.toString() ?? 'recorded',
      reviewedBy: json['reviewed_by']?.toString(),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      patientName: json['patients']?['full_name']?.toString(),
    );
  }
}
