import 'dart:convert';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class CallableHelper {
  static const String projectId = 'epl-3-the-brief';
  static const String region = 'us-central1';

  static bool _isWindows() => defaultTargetPlatform == TargetPlatform.windows;

  // Generic callable invoker. On Windows uses HTTPS REST endpoint.
  static Future<dynamic> callFunction(String name, Map<String, dynamic> data) async {
    if (!_isWindows()) {
      final functions = FirebaseFunctions.instanceFor(region: region);
      final callable = functions.httpsCallable(name);
      final result = await callable.call(data);
      return result.data;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }
    String? idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      idToken = await user.getIdToken(true);
    }
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Failed to obtain ID token');
    }

    // For admin-only functions and removeDevice, use explicit HTTP endpoints (with CORS and token verification)
    final bool useHttpEndpoint =
        name == 'adminDeleteUser' || name == 'adminSetUserAdminRole' || name == 'adminGetUserAdminRole' || name == 'adminRemoveDevice' || name == 'removeDevice';
    final endpoint = useHttpEndpoint ? '${name}Http' : name;
    final url = Uri.parse('https://$region-$projectId.cloudfunctions.net/$endpoint');
    final body = useHttpEndpoint ? jsonEncode(data) : jsonEncode({'data': data});
    Future<http.Response> _send(String token) {
      return http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );
    }
    var resp = await _send(idToken);
    if (resp.statusCode == 401) {
      // Refresh token and retry once
      final refreshed = await user.getIdToken(true);
      if (refreshed == null || refreshed.isEmpty) {
        throw StateError('Failed to refresh ID token');
      }
      resp = await _send(refreshed);
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    final decoded = jsonDecode(resp.body);
    return decoded is Map<String, dynamic> && decoded.containsKey('result')
        ? decoded['result']
        : decoded;
  }

  // Back-compat convenience
  static Future<dynamic> callAdminSetUserAdminRole({required String uid, required bool value}) {
    return callFunction('adminSetUserAdminRole', {'uid': uid, 'value': value});
  }
}
