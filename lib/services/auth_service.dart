import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Builds a minimal UserModel from Firebase Auth user (e.g. when Firestore is offline).
  UserModel _userModelFromFirebaseUser(User user) {
    final name = user.displayName ?? user.email ?? '';
    return UserModel(
      id: user.uid,
      email: user.email ?? '',
      fullNameAr: name,
      fullNameEn: name,
      phone: null,
      roles: const ['patient'],
      permissions: const [],
      isActive: true,
      createdAt: null,
      updatedAt: null,
    );
  }

  Future<UserModel?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return _userModelFromFirebaseUser(user);
      return UserModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.message?.contains('offline') == true) {
        return _userModelFromFirebaseUser(user);
      }
      rethrow;
    }
  }

  Future<UserModel?> signInWithEmailAndPassword(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    if (cred.user == null) return null;
    return getCurrentUserProfile();
  }

  /// Sign in with email or patient code. If [identifier] contains '@', treats as email; otherwise looks up user by patientCode and signs in with their email.
  Future<UserModel?> signInWithEmailOrPatientCode(String identifier, String password) async {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) return null;
    String email = trimmed;
    if (!trimmed.contains('@')) {
      final fs = FirestoreService();
      final user = await fs.getUserByPatientCode(trimmed);
      if (user == null) return null;
      email = user.email;
      if (email.isEmpty) return null;
    }
    return signInWithEmailAndPassword(email, password);
  }

  Future<UserModel?> signInWithGoogle() async {
    User? user;
    if (kIsWeb) {
      final cred = await _auth.signInWithPopup(GoogleAuthProvider());
      user = cred.user;
    } else {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      user = cred.user;
    }
    if (user == null) return null;
    final docRef = _firestore.collection('users').doc(user.uid);
    try {
      final doc = await docRef.get();
      if (!doc.exists) {
        final userModel = _userModelFromFirebaseUser(user);
        await docRef.set(userModel.toFirestore());
      }
      return getCurrentUserProfile();
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.message?.contains('offline') == true) {
        try {
          await docRef.set(_userModelFromFirebaseUser(user).toFirestore());
        } catch (_) {}
        return _userModelFromFirebaseUser(user);
      }
      rethrow;
    }
  }

  Future<UserModel?> registerWithEmailAndPassword({
    required String email,
    required String password,
    String? fullNameAr,
    String? fullNameEn,
    String? phone,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final user = cred.user;
    if (user == null) return null;

    var roles = <String>['patient'];
    final firestoreService = FirestoreService();
    final invite = await firestoreService.getInviteByEmail(user.email ?? email);
    if (invite != null) {
      roles = [invite['role'] as String? ?? 'patient'];
      await firestoreService.markInviteUsed(invite['id'] as String);
    }

    final userModel = UserModel(
      id: user.uid,
      email: user.email ?? email,
      fullNameAr: fullNameAr ?? invite?['fullNameAr'] as String?,
      fullNameEn: fullNameEn ?? invite?['fullNameEn'] as String?,
      phone: phone ?? invite?['phone'] as String?,
      roles: roles,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(user.uid).set(userModel.toFirestore());
    if (roles.contains('doctor')) {
      await firestoreService.ensureDoctorDocForUser(user.uid, user.displayName ?? user.email ?? '');
      final doc = await firestoreService.getDoctorByUserId(user.uid);
      if (doc != null && invite != null) {
        final updates = <String, dynamic>{};
        if (invite['specializationAr'] != null) updates['specializationAr'] = invite['specializationAr'];
        if (invite['specializationEn'] != null) updates['specializationEn'] = invite['specializationEn'];
        if (invite['qualificationsAr'] != null) updates['qualificationsAr'] = invite['qualificationsAr'];
        if (invite['qualificationsEn'] != null) updates['qualificationsEn'] = invite['qualificationsEn'];
        if (invite['certificationsAr'] != null) updates['certificationsAr'] = invite['certificationsAr'];
        if (invite['certificationsEn'] != null) updates['certificationsEn'] = invite['certificationsEn'];
        if (invite['bio'] != null) updates['bio'] = invite['bio'];
        if (updates.isNotEmpty) await firestoreService.updateDoctor(doc.id, updates);
      }
    }
    if (roles.contains('patient')) await firestoreService.ensurePatientCode(user.uid);
    return getCurrentUserProfile();
  }

  Future<void> signOut() async {
    if (!kIsWeb) await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Sends a password reset email to the given address. User receives a link to reset password.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// True if the current user signed in with email/password (can change password in-app).
  bool get currentUserHasPasswordProvider {
    final user = _auth.currentUser;
    if (user == null || user.email == null || user.email!.isEmpty) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  /// Reauthenticates with [currentPassword] then sets [newPassword]. Throws [FirebaseAuthException] on failure.
  Future<void> updatePassword(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-user', message: 'Not signed in');
    if (user.email == null || user.email!.isEmpty) throw FirebaseAuthException(code: 'no-email', message: 'No email');
    final credential = EmailAuthProvider.credential(email: user.email!, password: currentPassword.trim());
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword.trim());
  }

  Future<void> updateUserRoles(String uid, List<String> roles) async {
    await _firestore.collection('users').doc(uid).update({
      'roles': roles,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final fs = FirestoreService();
    if (roles.contains('doctor')) {
      final u = await fs.getUser(uid);
      await fs.ensureDoctorDocForUser(uid, u?.displayName ?? '');
    }
  }

  Future<void> updateUserPermissions(String uid, List<String> permissions) async {
    await _firestore.collection('users').doc(uid).update({
      'permissions': permissions,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserActive(String uid, bool isActive) async {
    await _firestore.collection('users').doc(uid).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Admin: update user profile fields (name, phone). Roles/permissions/active have dedicated methods.
  Future<void> updateUserProfile(String uid, {String? fullNameAr, String? fullNameEn, String? phone}) async {
    final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (fullNameAr != null) data['fullNameAr'] = fullNameAr;
    if (fullNameEn != null) data['fullNameEn'] = fullNameEn;
    if (phone != null) data['phone'] = phone;
    if (data.length <= 1) return;
    await _firestore.collection('users').doc(uid).update(data);
  }

  /// Admin: set starred (VIP) flag for a patient. Same star icon as "new patient" in schedule.
  Future<void> updateUserStarred(String uid, bool isStarred) async {
    await _firestore.collection('users').doc(uid).update({
      'isStarred': isStarred,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Admin: delete user document from Firestore. Does not remove Firebase Auth account (use Admin SDK/Cloud Function for that).
  Future<void> deleteUserDocument(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
  }
}
