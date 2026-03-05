import 'package:firebase_core/firebase_core.dart';

/// Keys for user-friendly error messages. Use with [AppLocalizations.generalErrorMessage].
abstract class GeneralErrorKey {
  static const permissionDenied = 'errorPermissionDenied';
  static const network = 'errorNetwork';
  static const saveFailed = 'errorSaveFailed';
  static const loadFailed = 'errorLoadFailed';
  static const tryAgain = 'errorTryAgain';
}

/// Maps Firestore and other exceptions to user-friendly message keys.
/// Use with AppLocalizations.generalErrorMessage(key) for localized text.
String generalErrorToMessageKey(Object error, [String? stackTrace]) {
  final msg = error.toString();
  final code = error is FirebaseException ? error.code : null;

  if (code != null) {
    switch (code) {
      case 'permission-denied':
      case 'cloud_firestore/permission-denied':
        return GeneralErrorKey.permissionDenied;
      case 'unavailable':
      case 'resource-exhausted':
        return GeneralErrorKey.network;
      default:
        break;
    }
  }
  final lower = msg.toLowerCase();
  if (lower.contains('permission') || lower.contains('permission-denied') || lower.contains('insufficient permissions')) {
    return GeneralErrorKey.permissionDenied;
  }
  if (lower.contains('network') || lower.contains('socket') || lower.contains('connection') || lower.contains('unavailable') || lower.contains('offline')) {
    return GeneralErrorKey.network;
  }
  return GeneralErrorKey.tryAgain;
}
