import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_ids.dart';
import 'ads_gate.dart';

/// Simple singleton manager for Interstitial ads
class InterstitialAdService {
  static InterstitialAd? _ad;
  static bool _isLoading = false;
  static DateTime? _lastShown;
  // Basic frequency cap: min seconds between shows
  static const int _minSecondsBetweenAds = 45;
  static Completer<InterstitialAd?>? _loadingCompleter;
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
    } catch (_) {
      // ignore errors; SDK may already be initialized
    }
    _initialized = true;
  }

  static String get _unitId => Platform.isAndroid
      ? AdIds.androidInterstitial
      : AdIds.iosInterstitial;

  static bool get _canShowByFrequency {
    if (_lastShown == null) return true;
    return DateTime.now().difference(_lastShown!).inSeconds >= _minSecondsBetweenAds;
  }

  static Future<void> loadIfNeeded() async {
    if (kIsWeb) return;
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    // Respect ads gate
    try {
      if (!await AdsGate.shouldShowAds()) return;
    } catch (_) {}
    await _ensureInitialized();
    if (_ad != null || _isLoading) return;
    _isLoading = true;
    _loadingCompleter = Completer<InterstitialAd?>();
    await InterstitialAd.load(
      adUnitId: _unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _isLoading = false;
          try { _loadingCompleter?.complete(ad); } catch (_) {}
          _loadingCompleter = null;
          // Ensure full-screen callbacks clean up
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _ad = null;
              // Preload next
              loadIfNeeded();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _ad = null;
              loadIfNeeded();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          _ad = null;
          try { _loadingCompleter?.complete(null); } catch (_) {}
          _loadingCompleter = null;
        },
      ),
    );
  }

  /// Show if an ad is loaded and basic frequency allows.
  /// Non-blocking: if not ready, just returns.
  static Future<void> showIfAvailable({bool force = false}) async {
    if (kIsWeb) return;
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    // Respect ads gate
    try {
      if (!await AdsGate.shouldShowAds()) return;
    } catch (_) {}

    // Attempt to load ahead if needed
    if (_ad == null && !_isLoading) {
      await loadIfNeeded();
    }

    // If still loading (first time), wait briefly for readiness
    if (_ad == null && _isLoading && _loadingCompleter != null) {
      try {
        // Wait up to 4 seconds; if not ready, just return and let next attempt show
        await _loadingCompleter!.future.timeout(const Duration(seconds: 4));
      } catch (_) {}
    }

    if (_ad == null) return;
    if (!force && !_canShowByFrequency) return;

    try {
      await _ad!.show();
      _lastShown = DateTime.now();
      // _ad will be disposed in callbacks; set null defensively
      _ad = null;
      // Preload a new one
      await loadIfNeeded();
    } catch (_) {
      // On any error, dispose and try to load next silently
      try { _ad?.dispose(); } catch (_) {}
      _ad = null;
      await loadIfNeeded();
    }
  }
}
