import 'package:firebase_auth/firebase_auth.dart';

/// Keys for auth error messages. Use with [AppLocalizations.authErrorMessage].
abstract class AuthErrorKey {
  static const invalidEmail = 'authErrorInvalidEmail';
  static const invalidCredentials = 'authErrorInvalidCredentials';
  static const emailAlreadyInUse = 'authErrorEmailAlreadyInUse';
  static const weakPassword = 'authErrorWeakPassword';
  static const accountDeactivated = 'authErrorAccountDeactivated';
  static const userDisabled = 'authErrorUserDisabled';
  static const tooManyRequests = 'authErrorTooManyRequests';
  static const networkError = 'authErrorNetwork';
  static const tryAgain = 'authErrorTryAgain';
  static const noAccountWithEmail = 'authErrorNoAccountWithEmail';
}

/// Maps Firebase/Firestore exceptions to user-friendly message keys for login/register.
/// Set [forResetPassword] true when handling sendPasswordResetEmail so user-not-found gets a specific message.
String authErrorToMessageKey(Object error, [String? stackTrace, bool forResetPassword = false]) {
  if (error is FirebaseAuthException) {
    if (forResetPassword && error.code == 'user-not-found') {
      return AuthErrorKey.noAccountWithEmail;
    }
    switch (error.code) {
      case 'invalid-email':
        return AuthErrorKey.invalidEmail;
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return AuthErrorKey.invalidCredentials;
      case 'email-already-in-use':
        return AuthErrorKey.emailAlreadyInUse;
      case 'weak-password':
        return AuthErrorKey.weakPassword;
      case 'user-disabled':
        return AuthErrorKey.userDisabled;
      case 'too-many-requests':
        return AuthErrorKey.tooManyRequests;
      case 'network-request-failed':
      case 'operation-not-allowed':
        return AuthErrorKey.networkError;
      default:
        return AuthErrorKey.tryAgain;
    }
  }
  if (error is FirebaseException) {
    if (error.code == 'unavailable' ||
        error.message?.toLowerCase().contains('offline') == true ||
        error.message?.toLowerCase().contains('network') == true) {
      return AuthErrorKey.networkError;
    }
    return AuthErrorKey.tryAgain;
  }
  final msg = error.toString().toLowerCase();
  if (msg.contains('network') || msg.contains('socket') || msg.contains('connection')) {
    return AuthErrorKey.networkError;
  }
  return AuthErrorKey.tryAgain;
}
