class SupportConversation {
  final int id;
  final String? faultReportId;
  final String workstationId;
  final String roomName;
  final String pcId;
  final String studentUid;
  final String studentName;
  final String studentId;
  final String studentEmail;
  final String category;
  final String subject;
  final String issue;
  final String details;
  final String severity;
  final String status;
  final bool linkedFault;
  final bool repaired;
  final int unreadCount;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SupportConversation({
    required this.id,
    required this.faultReportId,
    required this.workstationId,
    required this.roomName,
    required this.pcId,
    required this.studentUid,
    required this.studentName,
    required this.studentId,
    required this.studentEmail,
    required this.category,
    required this.subject,
    required this.issue,
    required this.details,
    required this.severity,
    required this.status,
    required this.linkedFault,
    required this.repaired,
    required this.unreadCount,
    this.lastMessage,
    this.lastMessageAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get canReply => !repaired && status != 'resolved' && status != 'closed';
  bool get hasLinkedFault => linkedFault && faultReportId != null;

  factory SupportConversation.fromJson(Map<String, dynamic> json) {
    final faultId = _nullable(json['fault_report_id']);
    final subject = (json['subject'] ?? json['issue'] ?? 'Support Request')
        .toString();
    return SupportConversation(
      id: _toInt(json['id'] ?? json['conversation_id']),
      faultReportId: faultId,
      workstationId: (json['workstation_id'] ?? '').toString(),
      roomName: (json['room_name'] ?? '').toString(),
      pcId: (json['pc_id'] ?? '').toString(),
      studentUid: (json['student_uid'] ?? '').toString(),
      studentName: (json['student_name'] ?? '').toString(),
      studentId: (json['student_id'] ?? '').toString(),
      studentEmail: (json['student_email'] ?? '').toString(),
      category: (json['category'] ?? 'general').toString(),
      subject: subject,
      issue: (json['issue'] ?? subject).toString(),
      details: (json['details'] ?? '').toString(),
      severity: (json['severity'] ?? 'normal').toString(),
      status: (json['status'] ?? 'open').toString().trim().toLowerCase(),
      linkedFault: _toBool(json['linked_fault']) || faultId != null,
      repaired: _toBool(json['repaired']),
      unreadCount: _toInt(json['unread_count']),
      lastMessage: _nullable(json['last_message']),
      lastMessageAt: DateTime.tryParse((json['last_message_at'] ?? '').toString()),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'yes';
  }

  static String? _nullable(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
