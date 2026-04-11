import 'package:flutter/foundation.dart' show kIsWeb;

/// OAuth 2.0 **Web client** ID from Firebase / Google Cloud (same project as the Android app).
/// Listed in `android/app/google-services.json` under `oauth_client` with `client_type: 3`.
/// Required on Android (and recommended on iOS) so Google Sign-In returns an **id token** for Firebase Auth.
const String _kGoogleServerClientId =
    '43994021992-eckl0n819oa76sh10mfknopdo1v6u000.apps.googleusercontent.com';

/// Pass to [GoogleSignIn] on mobile; unused on web (login uses Firebase popup).
String? get googleSignInServerClientId => kIsWeb ? null : _kGoogleServerClientId;
