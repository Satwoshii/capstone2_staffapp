class TeacherChatConversation {
  final int id;
  final String teacherUid;
  final String teacherName;
  final String teacherEmail;
  final String roomName;
  final String status;
  final int unreadCount;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TeacherChatConversation({
    required this.id,
    required this.teacherUid,
    required this.teacherName,
    required this.teacherEmail,
    required this.roomName,
    required this.status,
    required this.unreadCount,
    this.lastMessage,
    this.lastMessageAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isClosed => status == 'resolved' || status == 'closed';

  factory TeacherChatConversation.fromJson(Map<String, dynamic> json) {
    return TeacherChatConversation(
      id: _intValue(json['id'] ?? json['conversation_id']),
      teacherUid: (json['teacher_uid'] ?? '').toString(),
      teacherName: (json['teacher_name'] ?? 'Teacher').toString(),
      teacherEmail: (json['teacher_email'] ?? '').toString(),
      roomName: (json['room_name'] ?? '').toString(),
      status: (json['status'] ?? 'open').toString().trim().toLowerCase(),
      unreadCount: _intValue(json['unread_count']),
      lastMessage: _nullable(json['last_message']),
      lastMessageAt: _date(json['last_message_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

class TeacherChatMessage {
  final String id;
  final int conversationId;
  final String senderUid;
  final String senderRole;
  final String senderName;
  final String message;
  final DateTime createdAt;
  final bool read;

  const TeacherChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderUid,
    required this.senderRole,
    required this.senderName,
    required this.message,
    required this.createdAt,
    required this.read,
  });

  bool get isAdmin => senderRole == 'admin' || senderRole == 'super_admin';
  bool get isTeacher => senderRole == 'teacher';

  factory TeacherChatMessage.fromJson(Map<String, dynamic> json) {
    return TeacherChatMessage(
      id: (json['id'] ?? '').toString(),
      conversationId: _intValue(json['conversation_id']),
      senderUid: (json['sender_uid'] ?? '').toString(),
      senderRole: (json['sender_role'] ?? '').toString().trim().toLowerCase(),
      senderName: (json['sender_name'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: _date(json['created_at']) ?? DateTime.now(),
      read: _boolValue(json['read']),
    );
  }
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _boolValue(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == '1' || text == 'true' || text == 'yes';
}

String? _nullable(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

DateTime? _date(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
}
