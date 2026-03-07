import 'package:flutter/foundation.dart';
import '../core/auth_error_helper.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _loading = true;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  /// True if the current user can change password in-app (email/password sign-in).
  bool get canChangePassword => _authService.currentUserHasPasswordProvider;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    final user = _authService.currentUser;
    if (user != null) {
      await loadUserProfile();
    } else {
      _loading = false;
      notifyListeners();
    }
    _authService.authStateChanges.listen((user) async {
      if (user != null) {
        await loadUserProfile();
      } else {
        _currentUser = null;
        _loading = false;
        notifyListeners();
      }
    });
  }

  Future<void> loadUserProfile() async {
    final firebaseUser = _authService.currentUser;
    if (firebaseUser == null) {
      _currentUser = null;
      _loading = false;
      _error = null;
      notifyListeners();
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _currentUser = await _authService.getCurrentUserProfile();
    } catch (e, st) {
      // Race: right after registration, auth state listener may run before Firestore doc is visible. Retry once.
      if (_authService.currentUser != null) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (_authService.currentUser == null) {
          _currentUser = null;
          _error = authErrorToMessageKey(e, st.toString());
        } else {
          try {
            _currentUser = await _authService.getCurrentUserProfile();
          } catch (e2, _) {
            _error = authErrorToMessageKey(e2, null);
            _currentUser = null;
          }
        }
      } else {
        _error = authErrorToMessageKey(e, st.toString());
        _currentUser = null;
      }
    }
    _loading = false;
    notifyListeners();
    if (_currentUser != null) {
      NotificationService().refreshTokenAndScheduleReminders(_currentUser!.id);
    }
  }

  /// [emailOrPatientCode] can be either email or the patient's ID code for patients.
  Future<bool> signIn(String emailOrPatientCode, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final user = await _authService.signInWithEmailOrPatientCode(emailOrPatientCode, password);
      _currentUser = user;
      if (user != null && !user.isActive) {
        _error = AuthErrorKey.accountDeactivated;
        await _authService.signOut();
        _currentUser = null;
      }
    } catch (e, st) {
      _error = authErrorToMessageKey(e, st.toString());
      _currentUser = null;
    }
    _loading = false;
    notifyListeners();
    return _currentUser != null;
  }

  Future<bool> signInWithGoogle() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final user = await _authService.signInWithGoogle();
      _currentUser = user;
      if (user != null && !user.isActive) {
        _error = AuthErrorKey.accountDeactivated;
        await _authService.signOut();
        _currentUser = null;
      }
    } catch (e, st) {
      _error = authErrorToMessageKey(e, st.toString());
      _currentUser = null;
    }
    _loading = false;
    notifyListeners();
    return _currentUser != null;
  }

  Future<bool> register({
    required String email,
    required String password,
    String? fullNameAr,
    String? fullNameEn,
    String? phone,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final user = await _authService.registerWithEmailAndPassword(
        email: email,
        password: password,
        fullNameAr: fullNameAr,
        fullNameEn: fullNameEn,
        phone: phone,
      );
      _currentUser = user;
    } catch (e, st) {
      _error = authErrorToMessageKey(e, st.toString());
      _currentUser = null;
    }
    _loading = false;
    notifyListeners();
    return _currentUser != null;
  }

  Future<void> signOut() async {
    final uid = _currentUser?.id;
    if (uid != null) NotificationService().clearToken(uid);
    await _authService.signOut();
    _currentUser = null;
    _error = null;
    notifyListeners();
  }

  Future<void> updateUserRoles(String uid, List<String> roles) async {
    await _authService.updateUserRoles(uid, roles);
    if (_currentUser?.id == uid) {
      _currentUser = _currentUser!.copyWith(roles: roles);
      notifyListeners();
    }
  }

  Future<void> updateUserPermissions(String uid, List<String> permissions) async {
    await _authService.updateUserPermissions(uid, permissions);
    if (_currentUser?.id == uid) {
      _currentUser = _currentUser!.copyWith(permissions: permissions);
      notifyListeners();
    }
  }

  Future<void> updateUserActive(String uid, bool isActive) async {
    await _authService.updateUserActive(uid, isActive);
    if (_currentUser?.id == uid) {
      notifyListeners();
    }
  }

  Future<void> updateUserProfile(String uid, {String? fullNameAr, String? fullNameEn, String? phone}) async {
    await _authService.updateUserProfile(uid, fullNameAr: fullNameAr, fullNameEn: fullNameEn, phone: phone);
    if (_currentUser?.id == uid && (fullNameAr != null || fullNameEn != null || phone != null)) {
      _currentUser = _currentUser!.copyWith(
        fullNameAr: fullNameAr ?? _currentUser!.fullNameAr,
        fullNameEn: fullNameEn ?? _currentUser!.fullNameEn,
        phone: phone ?? _currentUser!.phone,
      );
      notifyListeners();
    }
  }

  Future<void> updateUserStarred(String uid, bool isStarred) async {
    await _authService.updateUserStarred(uid, isStarred);
  }

  /// Change password for current user (email/password only). Reauthenticates then updates.
  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _authService.updatePassword(currentPassword, newPassword);
  }

  Future<void> deleteUserDocument(String uid) async {
    await _authService.deleteUserDocument(uid);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
