class AppUser {
  static const String studentRole = 'student';
  static const String adminRole = 'admin';
  static const String superAdminRole = 'super_admin';

  static const allowedAccountRoles = {
    studentRole,
    adminRole,
    superAdminRole,
  };

  final String uid;
  final String email;
  final String displayName;
  final String role;
  final String? studentId;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.studentId,
    required this.active,
    this.createdAt,
    this.updatedAt,
  });

  bool get isSuperAdmin => role == superAdminRole;

  /// Super administrators are also allowed to use every normal admin screen.
  bool get isAdmin => role == adminRole || isSuperAdmin;

  bool get isStudent => role == studentRole;

  String get roleLabel {
    switch (role) {
      case superAdminRole:
        return 'SUPER ADMIN';
      case adminRole:
        return 'ADMIN';
      case studentRole:
        return 'STUDENT';
      default:
        return role.replaceAll('_', ' ').toUpperCase();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'display_name': displayName,
      'role': role,
      'student_id': studentId,
      'active': active,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final email = _string(json, ['email']);
    return AppUser(
      uid: _string(json, ['uid', 'id', 'user_id'], fallback: email),
      email: email,
      displayName: _string(
        json,
        ['display_name', 'displayName', 'name'],
        fallback: email,
      ),
      role: _normalizeRole(_string(json, ['role'], fallback: studentRole)),
      studentId: _nullableString(json, ['student_id', 'studentId']),
      active: _bool(json['active'], fallback: true),
      createdAt: _date(json['created_at'] ?? json['createdAt']),
      updatedAt: _date(json['updated_at'] ?? json['updatedAt']),
    );
  }
}

String _normalizeRole(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll(' ', '_');
  if (normalized == 'superadmin') return AppUser.superAdminRole;
  return normalized;
}

String _string(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = json[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }
  return fallback;
}

String? _nullableString(Map<String, dynamic> json, List<String> keys) {
  final value = _string(json, keys);
  return value.isEmpty ? null : value;
}

bool _bool(dynamic value, {required bool fallback}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return fallback;
}

DateTime? _date(dynamic value) {
  if (value == null || value.toString().trim().isEmpty) return null;
  return DateTime.tryParse(value.toString());
}
