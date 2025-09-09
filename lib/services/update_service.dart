import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:brie_fly/screens/update_required_page.dart';
import 'package:brie_fly/services/navigation_service.dart';

class UpdateService {
  static const String configUrl =
      'https://epl-3-the-brief.web.app/update.json'; // hosted on Firebase

  static Future<void> checkForMandatoryUpdate(BuildContext context) async {
    try {
      // Desktop/web only for now
      if (kIsWeb || !(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        debugPrint('[UpdateService] Skipping check: not desktop platform.');
        return;
      }

      debugPrint('[UpdateService] Starting mandatory update check…');
      final pkg = await PackageInfo.fromPlatform();
      final current = pkg.version; // e.g., 1.0.0 or 1.0.0+100 (platform-dependent)
      final currentBuild = int.tryParse(pkg.buildNumber) ?? 0;
      final buildKnown = currentBuild > 0; // On desktop, buildNumber may be unknown (0)
      debugPrint('[UpdateService] Current app version: $current (+$currentBuild, knownBuild=$buildKnown)');

      // Add cache-buster to avoid CDN caching of update.json
      final uri = Uri.parse('$configUrl?t=${DateTime.now().millisecondsSinceEpoch}');
      http.Response resp;
      try {
        resp = await http.get(uri).timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('[UpdateService] HTTP error fetching $configUrl: $e');
        return;
      }
      if (resp.statusCode != 200) {
        debugPrint('[UpdateService] HTTP ${resp.statusCode} from $configUrl');
        return;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final latest = (data['latest_version'] as String).trim();
      final latestBuildField = data['latest_build'];
      final latestBuild = latestBuildField is int
          ? latestBuildField
          : int.tryParse('${latestBuildField ?? ''}') ?? _parseVersion(latest).build;
      final mandatory = (data['mandatory'] as bool?) ?? false;
      final installerUrl = (data['installer_url'] as String?) ?? '';
      final notes = (data['notes'] as String?) ?? '';
      final minSupportedBuildField = data['min_supported_build'];
      final minSupportedBuild = minSupportedBuildField is int
          ? minSupportedBuildField
          : int.tryParse('${minSupportedBuildField ?? ''}');

      debugPrint('[UpdateService] Remote latest: $latest (+$latestBuild), mandatory: $mandatory, minSupportedBuild=${minSupportedBuild ?? 'n/a'}');
      if (!mandatory) {
        debugPrint('[UpdateService] Not mandatory, skipping.');
        return;
      }
      // Prefer buildNumber from PackageInfo when available
      final curV = _parseVersion(current, overrideBuild: buildKnown ? currentBuild : null);
      final latV = _parseVersion(latest, overrideBuild: latestBuild);
      // Desktop tolerance: If build is unknown (0) and core version matches latest, treat as up-to-date.
      final coreEqual = curV.major == latV.major && curV.minor == latV.minor && curV.patch == latV.patch;

      // Only enforce minSupportedBuild when current build is known (>0)
      if (minSupportedBuild != null && buildKnown && curV.build < minSupportedBuild) {
        debugPrint('[UpdateService] Current build ${curV.build} < min supported $minSupportedBuild (build known): forcing update');
      } else {
        if (!buildKnown && coreEqual) {
          debugPrint('[UpdateService] Core version equals latest and build unknown; treating as up to date. current=$curV latest=$latV');
          return;
        }
        final cmp = _compareVersion(curV, latV);
        if (cmp >= 0) {
          debugPrint('[UpdateService] App is up to date (>= latest). current=$curV latest=$latV');
          return; // already up to date
        }
      }
      debugPrint('[UpdateService] Update required. Navigating to UpdateRequiredPage…');

      // Navigate to a full-screen blocking page that handles download and exit
      final nav = NavigationService.rootNavigatorKey.currentState;
      if (nav == null) {
        debugPrint('[UpdateService] rootNavigatorKey has no state yet; deferring navigation.');
        await Future.delayed(const Duration(milliseconds: 200));
      }
      final nav2 = NavigationService.rootNavigatorKey.currentState;
      if (nav2 == null) {
        debugPrint('[UpdateService] Still no Navigator available; giving up for now.');
        return;
      }
      final route = MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => UpdateRequiredPage(
          latestVersion: '${latV.major}.${latV.minor}.${latV.patch}+${latV.build}',
          notes: notes,
          installerUrl: installerUrl,
        ),
      );
      if (kReleaseMode) {
        await nav2.pushAndRemoveUntil(route, (r) => false);
      } else {
        // In debug/profile, do not clear stack so we can pop to continue editing
        await nav2.push(route);
      }
    } catch (e, s) {
      // Best-effort; log details to help diagnose
      debugPrint('[UpdateService] Unexpected error during update check: $e');
      debugPrint('[UpdateService] Stack: $s');
    }
  }

  // Simple build-aware version model: major.minor.patch + optional build
  static _Version _parseVersion(String v, {int? overrideBuild}) {
    final parts = v.split('+');
    final core = parts.first;
    final build = overrideBuild ?? (parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0);
    final nums = core.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (nums.length < 3) nums.add(0);
    return _Version(nums[0], nums[1], nums[2], build);
  }

  // Compare returns negative if a < b, 0 if equal, positive if a > b
  static int _compareVersion(_Version a, _Version b) {
    final d1 = a.major - b.major;
    if (d1 != 0) return d1;
    final d2 = a.minor - b.minor;
    if (d2 != 0) return d2;
    final d3 = a.patch - b.patch;
    if (d3 != 0) return d3;
    return a.build - b.build;
  }

}

class _Version {
  final int major;
  final int minor;
  final int patch;
  final int build;
  const _Version(this.major, this.minor, this.patch, this.build);
  @override
  String toString() => '$major.$minor.$patch+$build';
}
