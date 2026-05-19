import 'package:flutter/foundation.dart';

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.type = 'patient_update',
    this.category = 'patient',
    this.priority = 'normal',
    this.entityType,
    this.entityId,
  });

  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final String type; // 'patient_update' | 'new_patient' | 'appointment'
  final String category; // patient | visit | followup | system
  final String priority; // normal | high | urgent
  final String? entityType; // 'followup_task' | 'agent_outside_visit' | 'dr_visit'
  final String? entityId;

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? timestamp,
    bool? isRead,
    String? type,
    String? category,
    String? priority,
    String? entityType,
    String? entityId,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      timestamp: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      isRead: json['is_read'] == true,
      type: json['type']?.toString() ?? json['category']?.toString() ?? 'system',
      category: json['category']?.toString() ?? 'system',
      priority: json['priority']?.toString() ?? 'normal',
      entityType: json['entity_type']?.toString(),
      entityId: json['entity_id']?.toString(),
    );
  }
}
