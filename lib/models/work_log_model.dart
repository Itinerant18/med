class WorkLogEntry {
  final String id;
  final String entityType;
  final String entityId;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String body;
  final DateTime createdAt;

  const WorkLogEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.body,
    required this.createdAt,
  });

  factory WorkLogEntry.fromJson(Map<String, dynamic> json) => WorkLogEntry(
    id: json['id'] as String,
    entityType: json['entity_type'] as String,
    entityId: json['entity_id'] as String,
    authorId: json['author_id'] as String,
    authorName: json['author_name'] as String,
    authorRole: json['author_role'] as String,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  String get roleLabel => switch (authorRole) {
    'head_doctor' => 'Head Doctor',
    'doctor' => 'Doctor',
    _ => 'Agent',
  };
}
