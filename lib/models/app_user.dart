import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  static const allowedAccountRoles = {'student', 'itso', 'admin'};
  static const firestoreAccountRoleValues = [
    'student',
    'Student',
    'STUDENT',
    'itso',
    'Itso',
    'ITSO',
    'admin',
    'Admin',
    'ADMIN',
  ];

  final String uid;
  final String email;
  final String displayName;
  final String role;
  final String? studentId;
  final String? passwordHash;
  final bool active;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.studentId,
    this.passwordHash,
    required this.active,
  });

  Map<String, dynamic> toLocalMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role,
      'studentId': studentId,
      'passwordHash': passwordHash,
      'active': active ? 1 : 0,
    };
  }

  factory AppUser.fromLocalMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      role: (map['role'] ?? 'student').toString().trim().toLowerCase(),
      studentId: map['studentId'],
      passwordHash: map['passwordHash'],
      active: map['active'] == 1 || map['active'] == true,
    );
  }

  factory AppUser.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) {
      throw const FormatException('The user profile is empty.');
    }

    final activeValue = data['active'];

    return AppUser(
      uid: document.id,
      email: (data['email'] ?? '').toString().trim(),
      displayName: (data['displayName'] ?? '').toString().trim(),
      role: (data['role'] ?? 'student').toString().trim().toLowerCase(),
      studentId: data['studentId']?.toString().trim(),
      passwordHash: data['passwordHash']?.toString(),
      active: activeValue == null ||
          activeValue == true ||
          activeValue == 1 ||
          activeValue.toString().toLowerCase() == 'true',
    );
  }
}
