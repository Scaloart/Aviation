import 'dart:io' show Platform;
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../firebase_options.dart';

class DeviceRegistryService {
  DeviceRegistryService._();

  static Future<void> ensureRegistered() async {
    final installationId = await _getInstallationId();
    final platform = _platformString();
    final deviceName = await _deviceName();

    try {
      // Ensure we have a signed-in user before calling callable (mobile)
      if (kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        final auth = FirebaseAuth.instance;
        var user = auth.currentUser;
        if (user == null) {
          user = await auth
              .authStateChanges()
              .firstWhere((u) => u != null)
              .timeout(const Duration(seconds: 15));
        }
        // Refresh ID token to ensure callable is authenticated server-side
        await user!.getIdToken(true);
      }
      // Ensure we call the correct region for callable functions on mobile
      const region = 'us-central1';
      final functions = FirebaseFunctions.instanceFor(region: region);
      final callable = functions.httpsCallable('registerDevice');
      await callable.call({
        'installationId': installationId,
        'platform': platform,
        'deviceName': deviceName,
      });
    } on MissingPluginException catch (_) {
      // Cloud Functions not available on this platform (e.g., Windows). Try REST fallback.
      if (kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS) rethrow;
      await _callRegisterDeviceRest(installationId, platform, deviceName);
      return;
    } on PlatformException catch (e) {
      // Some desktop builds may report platform channel errors for cloud_functions
      final msg = e.message ?? '';
      final code = e.code.toLowerCase();
      if ((Platform.isWindows || Platform.isLinux) &&
          (code.contains('unavailable') || msg.contains('cloud_functions_platform_interface'))) {
        await _callRegisterDeviceRest(installationId, platform, deviceName);
        return;
      }
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      // cloud_functions may wrap platform issues into FirebaseFunctionsException
      final msg = e.message ?? '';
      final code = e.code.toLowerCase();
      if (code == 'failed-precondition') {
        // Strict 2-device policy hit on server
        throw PlatformException(code: 'device_limit_reached', message: 'Device limit reached. Remove a device to continue.');
      }
      if (code == 'unauthenticated' && (kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
        // If callable failed to attach auth, explicitly use REST with ID token
        await _callRegisterDeviceRest(installationId, platform, deviceName);
        return;
      }
      if (Platform.isWindows || Platform.isLinux) {
        // On desktop, allow proceed for unknown/unavailable errors
        if (code.contains('unavailable') || code.contains('unknown') || msg.contains('pigeon') || msg.contains('platform')) {
          await _callRegisterDeviceRest(installationId, platform, deviceName);
          return;
        }
      }
      rethrow;
    }
  }

  static Future<void> _callRegisterDeviceRest(
    String installationId,
    String platform,
    String deviceName,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw PlatformException(code: 'unauthenticated', message: 'User not signed in');
    }
    // Force-refresh the ID token to avoid using a stale/invalid token
    final idToken = await user.getIdToken(true);
    final projectId = _getProjectId();
    // Default region used in functions code is us-central1
    const region = 'us-central1';
    final url = Uri.parse('https://$region-$projectId.cloudfunctions.net/registerDeviceHttp');

    final resp = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: '{"installationId": "${_escape(installationId)}", "platform": "${_escape(platform)}", "deviceName": "${_escape(deviceName)}"}',
    );
    if (resp.statusCode >= 400) {
      if (resp.statusCode == 409) {
        throw PlatformException(code: 'device_limit_reached', message: 'Device limit reached. Remove a device to continue.');
      }
      if (resp.statusCode == 401) {
        throw PlatformException(
          code: 'functions_rest_unauthenticated',
          message:
              '401 from registerDevice. Check that projectId ("$projectId") matches your deployed functions project and that the region ("$region") is correct. Body: ${resp.body}',
        );
      }
      throw PlatformException(
        code: 'functions_rest_error',
        message: 'registerDevice failed via REST: ${resp.statusCode} ${resp.body}',
      );
    }
  }

  static String _escape(String s) => s.replaceAll('"', '\\"');

  static String _getProjectId() {
    try {
      final pid = Firebase.app().options.projectId;
      if (pid != null && pid.isNotEmpty) return pid;
    } catch (_) {
      // ignore and try fallback
    }
    // Fallback to FlutterFire generated options
    final fallback = DefaultFirebaseOptions.currentPlatform.projectId;
    if (fallback.isNotEmpty) return fallback;
    throw PlatformException(code: 'no_project_id', message: 'Firebase projectId not configured');
  }

  static Future<String> _getInstallationId() async {
    // Try Firebase Installations when available (web, android, ios, macos)
    try {
      final id = await FirebaseInstallations.instance.getId();
      if (id.isNotEmpty) return id;
    } on MissingPluginException {
      // Not implemented on this platform (e.g., Windows/Linux). Fall through to local ID.
    } catch (_) {
      // Fall through
    }

    // Fallback: persist a locally generated ID in secure storage so it remains stable per install
    const storage = FlutterSecureStorage();
    const key = 'localInstallationId';
    String? localId = await storage.read(key: key);
    if (localId == null || localId.isEmpty) {
      localId = _randomId();
      await storage.write(key: key, value: localId);
    }
    return localId;
  }

  static String _randomId([int length = 32]) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  static String _platformString() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
    }

  static Future<String> _deviceName() async {
    final info = DeviceInfoPlugin();
    try {
      if (kIsWeb) {
        final w = await info.webBrowserInfo;
        return '${w.browserName.name} ${w.userAgent ?? ''}'.trim();
      }
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        return '${a.manufacturer} ${a.model}'.trim();
      }
      if (Platform.isIOS) {
        final i = await info.iosInfo;
        return i.name ?? 'iPhone';
      }
      if (Platform.isWindows) {
        final w = await info.windowsInfo;
        return w.computerName ?? 'Windows PC';
      }
      if (Platform.isMacOS) {
        final m = await info.macOsInfo;
        return m.computerName ?? 'macOS';
      }
      if (Platform.isLinux) {
        final l = await info.linuxInfo;
        return l.name ?? 'Linux';
      }
    } catch (_) {}
    return 'Unknown Device';
  }
}
