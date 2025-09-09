import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:brie_fly/services/ads/ad_ids.dart';
import 'package:brie_fly/services/ads/ads_gate.dart';

/// Simple reusable banner ad that fits at the bottom of a page.
/// Uses standard Banner size for broad compatibility.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _banner;
  bool _loaded = false;

  String get _unitId => Platform.isAndroid
      ? AdIds.androidBanner
      : AdIds.iosBanner;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _maybeInit();
    }
  }

  Future<void> _maybeInit() async {
    try {
      if (!await AdsGate.shouldShowAds()) {
        setState(() { _loaded = false; _banner = null; });
        return;
      }
    } catch (_) {}
    await _initialize();
  }

  Future<void> _initialize() async {
    try {
      await MobileAds.instance.initialize();
    } catch (_) {}
    final banner = BannerAd(
      size: AdSize.banner,
      adUnitId: _unitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _loaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    try {
      await banner.load();
      if (mounted) {
        setState(() => _banner = banner);
      } else {
        banner.dispose();
      }
    } catch (_) {
      banner.dispose();
    }
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_banner == null || !_loaded) {
      // When ads are disabled or not yet loaded, keep minimal spacer to avoid jumps
      return const SizedBox(height: 8);
    }
    // Return only the AdWidget within a SizedBox to provide required size constraints.
    return SizedBox(
      height: _banner!.size.height.toDouble(),
      width: _banner!.size.width.toDouble(),
      child: AdWidget(ad: _banner!),
    );
  }
}
