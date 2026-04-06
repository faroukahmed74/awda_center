import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

/// Calls a 1st-gen Firebase **HTTPS callable** via HTTP + ID token.
///
/// Avoids the iOS/macOS [cloud_functions] native plugin, which can crash with
/// `HTTPSCallable.swift` / Swift concurrency (`swift_task_dealloc`) on Apple platforms.
///
/// Must match the region where functions are deployed (`firebase deploy` default is [defaultRegion]).
const String kFirebaseCallableRegion = 'us-central1';

Future<Map<String, dynamic>> callHttpsCallableHttp(
  String functionName,
  Map<String, dynamic> data,
) async {
  final projectId = Firebase.app().options.projectId;
  if (projectId.isEmpty) {
    throw Exception('Firebase projectId missing');
  }
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('Not signed in');
  }
  final token = await user.getIdToken();
  final url = Uri.parse(
    'https://$kFirebaseCallableRegion-$projectId.cloudfunctions.net/$functionName',
  );
  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({'data': data}),
  );

  Map<String, dynamic>? decoded;
  try {
    final parsed = jsonDecode(response.body);
    if (parsed is Map) {
      decoded = Map<String, dynamic>.from(parsed);
    }
  } catch (_) {
    throw Exception('Invalid JSON from Cloud Function (${response.statusCode}): ${response.body}');
  }

  if (decoded == null) {
    throw Exception('Empty response from Cloud Function (${response.statusCode})');
  }

  if (decoded.containsKey('error')) {
    final err = decoded['error'];
    var msg = 'Cloud function error';
    if (err is Map) {
      msg = err['message']?.toString() ?? err['status']?.toString() ?? msg;
    } else {
      msg = err.toString();
    }
    throw Exception(msg);
  }

  final result = decoded['result'];
  if (result is Map) {
    return Map<String, dynamic>.from(result);
  }
  throw Exception('Unexpected callable response: $decoded');
}
