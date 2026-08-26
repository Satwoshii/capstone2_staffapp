class LastKnownUserRecord {
  final String workstationId;
  final String roomName;
  final String pcId;
  final String displayName;
  final String email;
  final String status;
  final DateTime? loginTime;
  final DateTime? logoutTime;
  final String loginSource;

  const LastKnownUserRecord({
    required this.workstationId,
    required this.roomName,
    required this.pcId,
    required this.displayName,
    required this.email,
    required this.status,
    this.loginTime,
    this.logoutTime,
    this.loginSource = 'legacy',
  });

  bool get isWindowsLogin => loginSource.toLowerCase() == 'windows';

  String get dashboardDisplayName {
    final value = displayName.trim();
    if (value.isEmpty || value.contains('\\') || _looksLikeEmail(value)) {
      return 'Windows User';
    }
    return value;
  }

  factory LastKnownUserRecord.fromJson(Map<String, dynamic> json) {
    return LastKnownUserRecord(
      workstationId: (json['workstation_id'] ?? '').toString(),
      roomName: (json['room_name'] ?? '').toString(),
      pcId: (json['pc_id'] ?? '').toString(),
      displayName: (json['display_name'] ?? 'Windows User').toString(),
      email: (json['email'] ?? '').toString(),
      status: (json['status'] ?? 'unknown').toString(),
      loginTime: DateTime.tryParse((json['login_time'] ?? '').toString()),
      logoutTime: DateTime.tryParse((json['logout_time'] ?? '').toString()),
      loginSource: (json['login_source'] ?? 'legacy').toString(),
    );
  }

  static bool _looksLikeEmail(String value) {
    final text = value.trim();
    final at = text.indexOf('@');
    return at > 0 && at < text.length - 3 && text.substring(at + 1).contains('.');
  }
}
