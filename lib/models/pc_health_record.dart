import 'dart:convert';

class PcHealthRecord {
  final String id;
  final String workstationId;
  final String roomName;
  final String pcId;
  final String status;
  final DateTime? lastCheck;
  final String? lastStudentEmail;
  final dynamic details;

  const PcHealthRecord({
    required this.id,
    required this.workstationId,
    required this.roomName,
    required this.pcId,
    required this.status,
    this.lastCheck,
    this.lastStudentEmail,
    this.details,
  });

  factory PcHealthRecord.fromJson(Map<String, dynamic> json) {
    dynamic details = json['details'];
    if (details is String && details.trim().isNotEmpty) {
      try {
        details = jsonDecode(details);
      } catch (_) {
        // Keep plain text details.
      }
    }
    return PcHealthRecord(
      id: (json['id'] ?? '').toString(),
      workstationId: (json['workstation_id'] ?? '').toString(),
      roomName: (json['room_name'] ?? '').toString(),
      pcId: (json['pc_id'] ?? '').toString(),
      status: (json['status'] ?? 'unknown').toString(),
      lastCheck: DateTime.tryParse((json['last_check'] ?? '').toString()),
      lastStudentEmail: _nullable(json['last_student_email']),
      details: details,
    );
  }

  static String? _nullable(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
