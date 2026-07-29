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
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw Exception('Enter your staff email and password.');
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final authenticatedUser = credential.user;
      if (authenticatedUser == null) {
        throw Exception('Firebase did not return an authenticated user.');
      }

      try {
        final document =
            await _firestore.collection('users').doc(authenticatedUser.uid).get();

        if (!document.exists) {
          throw Exception('This account has no Firestore user profile.');
        }

        final user = AppUser.fromFirestore(document);
        final role = user.role;

        if (!user.active) {
          throw Exception('This account is disabled.');
        }

        if (role != 'admin' && role != 'itso') {
          throw Exception('Access denied. Use an ITSO or Admin account.');
        }

        return user;
      } catch (_) {
        await _auth.signOut();
        rethrow;
      }
    } on FirebaseAuthException catch (error) {
      throw Exception(_friendlyAuthMessage(error));
    }
  }

  static Future<void> createAccount({
    required String email,
    required String password,
    required String displayName,
    required String role,
    String? studentId,
    bool active = true,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
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

    if (!AppUser.allowedAccountRoles.contains(cleanRole)) {
      throw Exception('Role must be admin, itso, or student.');
    }

    if (cleanRole == 'student' &&
        (cleanStudentId == null || cleanStudentId.isEmpty)) {
      throw Exception('Student ID is required for student accounts.');
    }

    await _ensureUniqueProfile(
      email: cleanEmail,
      displayName: cleanDisplayName,
      studentId: cleanRole == 'student' ? cleanStudentId : null,
    );

    final secondaryAppName =
        'accountCreator_${DateTime.now().microsecondsSinceEpoch}';
    final secondaryApp = await Firebase.initializeApp(
      name: secondaryAppName,
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    User? createdUser;
    var profileCreated = false;

    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      createdUser = credential.user;
      if (createdUser == null) {
        throw Exception('Firebase did not return the newly created user.');
      }

      final uid = createdUser.uid;
      await createdUser.updateDisplayName(cleanDisplayName);
      final passwordHash = sha256.convert(utf8.encode(password)).toString();

      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': cleanEmail,
        'displayName': cleanDisplayName,
        'role': cleanRole,
        'active': active,
        'studentId': cleanRole == 'student' ? cleanStudentId : '',
        'passwordHash': cleanRole == 'student' ? passwordHash : '',
        'emailLower': cleanEmail,
        'displayNameLower': cleanDisplayName.toLowerCase(),
        'studentIdNormalized':
            cleanRole == 'student' ? cleanStudentId!.toLowerCase() : '',
        'department': 'SEAT',
        'program': cleanRole == 'student' ? 'BSIT-MWA' : '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': _auth.currentUser?.uid ?? '',
      });
      profileCreated = true;
    } on FirebaseAuthException catch (error) {
      final orphanedUser = createdUser;
      if (!profileCreated && orphanedUser != null) {
        await _deleteCreatedUserQuietly(orphanedUser);
      }
      throw Exception(_friendlyAuthMessage(error));
    } catch (_) {
      final orphanedUser = createdUser;
      if (!profileCreated && orphanedUser != null) {
        await _deleteCreatedUserQuietly(orphanedUser);
      }
      rethrow;
    } finally {
      try {
        await secondaryAuth.signOut();
      } catch (_) {
        // Deleting the temporary Firebase app also clears its Auth session.
      }
      try {
        await secondaryApp.delete();
      } catch (_) {
        // Cleanup must not make a successfully created account look like a failure.
      }
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  static Future<void> _ensureUniqueProfile({
    required String email,
    required String displayName,
    String? studentId,
  }) async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', whereIn: AppUser.firestoreAccountRoleValues)
        .get();

    final normalizedName = displayName.toLowerCase();
    final normalizedStudentId = studentId?.toLowerCase();

    for (final document in snapshot.docs) {
      final data = document.data();
      final existingEmail =
          (data['emailLower'] ?? data['email'] ?? '').toString().trim().toLowerCase();
      final existingName = (data['displayNameLower'] ??
              data['displayName'] ??
              '')
          .toString()
          .trim()
          .toLowerCase();
      final existingStudentId = (data['studentIdNormalized'] ??
              data['studentId'] ??
              '')
          .toString()
          .trim()
          .toLowerCase();

      if (existingEmail == email) {
        throw Exception('An account with this email already exists.');
      }
      if (existingName == normalizedName) {
        throw Exception('An account with this display name already exists.');
      }
      if (normalizedStudentId != null &&
          normalizedStudentId.isNotEmpty &&
          existingStudentId == normalizedStudentId) {
        throw Exception('An account with this Student ID already exists.');
      }
    }
  }

  static Future<void> _deleteCreatedUserQuietly(User user) async {
    try {
      await user.delete();
    } catch (_) {
      // The original account-creation error is more useful to the caller.
    }
  }

  static String _friendlyAuthMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This Firebase Authentication account is disabled.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Use a stronger password with at least 6 characters.';
      case 'network-request-failed':
        return 'Cannot connect to Firebase. Check the internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a moment and try again.';
      default:
        return error.message ?? 'Firebase Authentication failed.';
    }
  }
}
