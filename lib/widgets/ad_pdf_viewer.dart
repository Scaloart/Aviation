import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:brie_fly/services/ads/interstitial_ad_service.dart';
import 'package:brie_fly/services/ads/ads_gate.dart';

/// Wrapper around PdfViewer that attempts to show an interstitial ad
/// when the viewer first appears (mobile only, frequency capped).
class AdPdfViewer extends StatefulWidget {
  final PdfViewerController? controller;
  final PdfViewerParams? params;
  final Uri? uri;
  final Uint8List? data;
  final String? sourceName;

  const AdPdfViewer._({
    super.key,
    this.controller,
    this.params,
    this.uri,
    this.data,
    this.sourceName,
  });

  factory AdPdfViewer.uri(
    Uri uri, {
    Key? key,
    PdfViewerController? controller,
    PdfViewerParams? params,
  }) => AdPdfViewer._(
        key: key,
        controller: controller,
        params: params,
        uri: uri,
      );

  factory AdPdfViewer.data(
    Uint8List bytes, {
    Key? key,
    String? sourceName,
    PdfViewerController? controller,
    PdfViewerParams? params,
  }) => AdPdfViewer._(
        key: key,
        controller: controller,
        params: params,
        data: bytes,
        sourceName: sourceName,
      );

  @override
  State<AdPdfViewer> createState() => _AdPdfViewerState();
}

class _AdPdfViewerState extends State<AdPdfViewer> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _shown) return;
      _shown = true;
      try {
        if (await AdsGate.shouldShowAds()) {
          await InterstitialAdService.loadIfNeeded();
          await InterstitialAdService.showIfAvailable();
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uri != null) {
      return PdfViewer.uri(
        widget.uri!,
        controller: widget.controller,
        params: widget.params ?? const PdfViewerParams(),
      );
    }
    if (widget.data != null) {
      return PdfViewer.data(
        widget.data!,
        sourceName: widget.sourceName ?? 'document.pdf',
        controller: widget.controller,
        params: widget.params ?? const PdfViewerParams(),
      );
    }
    return const SizedBox.shrink();
  }
}
