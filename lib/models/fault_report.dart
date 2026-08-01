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
  final bool repaired;
  final DateTime? repairedAt;
  final String? technicianNotes;

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
    required this.repaired,
    this.repairedAt,
    this.technicianNotes,
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
      repaired: _toBool(json['repaired']),
      repairedAt: DateTime.tryParse((json['repaired_at'] ?? '').toString()),
      technicianNotes: _nullable(json['technician_notes']),
    );
  }

  static String? _nullable(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value.toString() == '1' || value.toString().toLowerCase() == 'true';
  }
}
