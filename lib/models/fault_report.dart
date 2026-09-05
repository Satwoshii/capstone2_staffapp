class FaultReport {
  final String id;
  final String workstationId;
  final String roomName;
  final String pcId;
  final String? studentEmail;
  final String issue;
  final String details;
  final String severity;
  final String source;
  final bool detectedBySystem;
  final DateTime? createdAt;
  final String workflowStatus;
  final bool repaired;
  final DateTime? repairedAt;
  final String? technicianNotes;
  final String? teacherNotes;
  final DateTime? teacherApprovedAt;
  final String? acceptedByName;
  final DateTime? acceptedAt;
  final String? handledByName;
  final DateTime? handledAt;
  final String? completedByName;
  final DateTime? completedAt;
  final int? queuePosition;
  final int? queueTotal;
  final bool isNextInQueue;
  final DateTime? queuedAt;

  const FaultReport({
    required this.id,
    required this.workstationId,
    required this.roomName,
    required this.pcId,
    this.studentEmail,
    required this.issue,
    required this.details,
    required this.severity,
    required this.source,
    required this.detectedBySystem,
    this.createdAt,
    required this.workflowStatus,
    required this.repaired,
    this.repairedAt,
    this.technicianNotes,
    this.teacherNotes,
    this.teacherApprovedAt,
    this.acceptedByName,
    this.acceptedAt,
    this.handledByName,
    this.handledAt,
    this.completedByName,
    this.completedAt,
    this.queuePosition,
    this.queueTotal,
    this.isNextInQueue = false,
    this.queuedAt,
  });

  factory FaultReport.fromJson(Map<String, dynamic> json) {
    return FaultReport(
      id: (json['id'] ?? '').toString(),
      workstationId: (json['workstation_id'] ?? '').toString(),
      roomName: (json['room_name'] ?? '').toString(),
      pcId: (json['pc_id'] ?? '').toString(),
      studentEmail: _nullable(json['student_email']),
      issue: (json['issue'] ?? 'Unknown issue').toString(),
      details: (json['details'] ?? '').toString(),
      severity: (json['severity'] ?? 'medium').toString(),
      source: (json['source'] ?? 'student_pc').toString(),
      detectedBySystem: _toBool(json['detected_by_system']),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      workflowStatus: (json['workflow_status'] ??
              (_toBool(json['repaired']) ? 'resolved' : 'reported'))
          .toString(),
      repaired: _toBool(json['repaired']),
      repairedAt: DateTime.tryParse((json['repaired_at'] ?? '').toString()),
      technicianNotes: _nullable(json['technician_notes']),
      teacherNotes: _nullable(json['teacher_notes']),
      teacherApprovedAt: DateTime.tryParse(
        (json['teacher_approved_at'] ?? '').toString(),
      ),
      acceptedByName: _nullable(json['accepted_by_name']),
      acceptedAt: DateTime.tryParse((json['accepted_at'] ?? '').toString()),
      handledByName: _nullable(json['handled_by_name']),
      handledAt: DateTime.tryParse((json['handled_at'] ?? '').toString()),
      completedByName: _nullable(json['completed_by_name']),
      completedAt: DateTime.tryParse((json['completed_at'] ?? '').toString()),
      queuePosition: _toNullableInt(json['queue_position']),
      queueTotal: _toNullableInt(json['queue_total']),
      isNextInQueue: _toBool(json['is_next_in_queue']),
      queuedAt: DateTime.tryParse((json['queued_at'] ?? json['created_at'] ?? '').toString()),
    );
  }

  static String? _nullable(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static int? _toNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value.toString() == '1' || value.toString().toLowerCase() == 'true';
  }
}
