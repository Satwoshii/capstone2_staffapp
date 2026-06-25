import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
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

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return AppUser(
      uid: data['uid'] ?? doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      role: (data['role'] ?? 'student').toString().trim().toLowerCase(),
      studentId: data['studentId'],
      passwordHash: data['passwordHash'],
      active: data['active'] ?? true,
    );
  }
}
