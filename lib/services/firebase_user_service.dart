import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../models/app_user.dart';

class FirebaseUserService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<AppUser> loginStaff({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;
    final doc = await _firestore.collection('users').doc(uid).get();

    if (!doc.exists) {
      throw Exception('User profile does not exist in Firestore users/$uid.');
    }

    final user = AppUser.fromFirestore(doc);
    final role = user.role.trim().toLowerCase();

    if (!user.active) {
      throw Exception('This account is disabled.');
    }

    if (role != 'admin' && role != 'itso') {
      throw Exception('Access denied. Staff app is only for ITSO/Admin.');
    }

    return user;
  }

  static Future<void> createAccount({
    required String email,
    required String password,
    required String displayName,
    required String role,
    String? studentId,
    bool active = true,
  }) async {
    final cleanEmail = email.trim();
    final cleanRole = role.trim().toLowerCase();
    final cleanDisplayName = displayName.trim();
    final cleanStudentId = studentId?.trim();

    if (cleanEmail.isEmpty) {
      throw Exception('Email is required.');
    }

    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    if (cleanDisplayName.isEmpty) {
      throw Exception('Display name is required.');
    }

    if (cleanRole != 'admin' && cleanRole != 'itso' && cleanRole != 'student') {
      throw Exception('Role must be admin, itso, or student.');
    }

    if (cleanRole == 'student' && (cleanStudentId == null || cleanStudentId.isEmpty)) {
      throw Exception('Student ID is required for student accounts.');
    }

    final secondaryAppName = 'accountCreator_${DateTime.now().microsecondsSinceEpoch}';
    final secondaryApp = await Firebase.initializeApp(
      name: secondaryAppName,
      options: DefaultFirebaseOptions.currentPlatform,
    );

    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final uid = credential.user!.uid;
      await credential.user!.updateDisplayName(cleanDisplayName);

      final passwordHash = sha256.convert(utf8.encode(password)).toString();

      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': cleanEmail,
        'displayName': cleanDisplayName,
        'role': cleanRole,
        'active': active,
        'studentId': cleanRole == 'student' ? cleanStudentId : '',
        'passwordHash': cleanRole == 'student' ? passwordHash : '',
        'department': 'SEAT',
        'program': cleanRole == 'student' ? 'BSIT-MWA' : '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': _auth.currentUser?.uid ?? '',
      }, SetOptions(merge: true));

      await secondaryAuth.signOut();
    } finally {
      await secondaryApp.delete();
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }
}
