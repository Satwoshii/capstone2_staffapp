class LastKnownUserRecord {
  final String workstationId;
  final String roomName;
  final String pcId;
  final String? uid;
  final String? studentId;
  final String? email;
  final String displayName;
  final String status;
  final DateTime? loginTime;
  final DateTime? logoutTime;

  const LastKnownUserRecord({
    required this.workstationId,
    required this.roomName,
    required this.pcId,
    this.uid,
    this.studentId,
    this.email,
    required this.displayName,
    required this.status,
    this.loginTime,
    this.logoutTime,
  });

  factory LastKnownUserRecord.fromJson(Map<String, dynamic> json) {
    return LastKnownUserRecord(
      workstationId: (json['workstation_id'] ?? '').toString(),
      roomName: (json['room_name'] ?? '').toString(),
      pcId: (json['pc_id'] ?? '').toString(),
      uid: _nullable(json['uid']),
      studentId: _nullable(json['student_id']),
      email: _nullable(json['email']),
      displayName: (json['display_name'] ?? json['email'] ?? 'Unknown user')
          .toString(),
      status: (json['status'] ?? 'unknown').toString(),
      loginTime: DateTime.tryParse((json['login_time'] ?? '').toString()),
      logoutTime: DateTime.tryParse((json['logout_time'] ?? '').toString()),
    );
  }

  static String? _nullable(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
