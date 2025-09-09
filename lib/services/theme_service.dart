import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;

class ThemeService with ChangeNotifier {
  static const String _backgroundKey = 'selected_background';
  late SharedPreferences _prefs;

  String _selectedBackground = '';

  ThemeService() {
    _loadBackground();
  }

  String get selectedBackground {
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    if (isDesktop) {
      return _selectedBackground.isEmpty ? 'assets/background_desktop.jpg' : _selectedBackground;
    } else {
      // Mobile: use saved selection if any, else default
      return _selectedBackground.isEmpty ? 'assets/background.jpg' : _selectedBackground;
    }
  }

  List<String> _availableBackgrounds = [];

  List<String> get availableBackgrounds => _availableBackgrounds;

  Future<void> _loadBackground() async {
    _prefs = await SharedPreferences.getInstance();
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    // Load saved selection (applies across platforms)
    _selectedBackground = _prefs.getString(_backgroundKey) ?? '';

    // Refresh available backgrounds based on platform
    await _refreshAvailableBackgrounds(isDesktop: isDesktop);
    notifyListeners();
  }

  Future<void> _refreshAvailableBackgrounds({required bool isDesktop}) async {
    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestJson) as Map<String, dynamic>;
      final String folder = isDesktop
          ? 'assets/desktop backgrounds options/'
          : 'assets/mobile backgrounds options/';
      final List<String> images = manifestMap.keys
          .where((k) => k.startsWith(folder) &&
              (k.endsWith('.jpg') || k.endsWith('.png') || k.endsWith('.jpeg') || k.endsWith('.webp')))
          .toList()
        ..sort();
      if (isDesktop) {
        _availableBackgrounds = ['assets/background_desktop.jpg', ...images];
      } else {
        // Always include the current default mobile background at the front
        _availableBackgrounds = ['assets/background.jpg', ...images];
      }
    } catch (_) {
      // If manifest load fails, keep whatever we already have.
      if (isDesktop) {
        if (_availableBackgrounds.isEmpty) {
          _availableBackgrounds = ['assets/background_desktop.jpg'];
        }
      } else {
        if (_availableBackgrounds.isEmpty) {
          _availableBackgrounds = ['assets/background.jpg'];
        }
      }
    }
  }

  Future<void> setBackground(String backgroundPath) async {
    _selectedBackground = backgroundPath;
    await _prefs.setString(_backgroundKey, backgroundPath);
    notifyListeners();
  }

  Future<void> clearBackground() async {
    _selectedBackground = ''; // Reset to default
    await _prefs.remove(_backgroundKey);
    notifyListeners();
  }
}
