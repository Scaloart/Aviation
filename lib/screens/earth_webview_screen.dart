import 'dart:io';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as wvw;

class EarthWebViewScreen extends StatefulWidget {
  /// Optional direct Google Earth deep link (preferred if provided).
  /// Example: https://earth.google.com/web/@.../data=...
  final String? earthDeepUrl;

  /// Optional HTTPS URL to a KMZ/KML to preload in Google Earth Web via kmlsrc.
  /// Used only if [earthDeepUrl] is null or empty.
  final String? kmzHttpsUrl;

  const EarthWebViewScreen({
    super.key,
    this.earthDeepUrl =
        'https://earth.google.com/web/@33.24276813,-6.42294804,353.46601858a,1040299.06294502d,30.00018603y,0h,0t,0r/data=CgRCAggBQgIIAEoICKnbs9cHEAA',
    this.kmzHttpsUrl,
  });

  @override
  State<EarthWebViewScreen> createState() => _EarthWebViewScreenState();
}

class _EarthWebViewScreenState extends State<EarthWebViewScreen> {
  WebViewController? _controller; // mobile/mac
  wvw.WebviewController? _winController; // windows
  bool _isLoading = true;
  String? _lastError;
  bool _didRetry = false;

  static const String _baseEarthUrl = 'https://earth.google.com/web';
  late final String _earthUrl;

  @override
  void initState() {
    super.initState();
    // Prefer a provided Earth deep link (already validated by user).
    final deep = widget.earthDeepUrl;
    if (deep != null && deep.isNotEmpty) {
      _earthUrl = deep;
    } else {
      // Fallback to kmlsrc if a KMZ URL is provided.
      final kmz = widget.kmzHttpsUrl;
      if (kmz != null && kmz.isNotEmpty) {
        final encoded = Uri.encodeComponent(kmz);
        _earthUrl = '$_baseEarthUrl?kmlsrc=$encoded';
      } else {
        _earthUrl = _baseEarthUrl;
      }
    }
    _initWebView();
  }

  void _initWebView() {
    if (Platform.isWindows) {
      _initWindowsWebView();
      return;
    }
    final c = WebViewController();
    _controller = c;
    // Use a desktop user agent to force full Earth Web (WebGL) instead of a limited mobile experience.
    const desktopUA =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

    c
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setUserAgent(desktopUA)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() {
            _isLoading = true;
            _lastError = null;
          }),
          onPageFinished: (_) async {
            setState(() => _isLoading = false);
            // Best-effort attempt to enter presentation/slideshow mode automatically.
            // This may change if Earth updates its UI; we silently ignore failures.
            try {
              await _controller?.runJavaScript(
                """
                (function tryPresent(){
                  // Attempt to click a button that starts presentation
                  const btn = document.querySelector('[aria-label*="Present"], [aria-label*="Présentation"], button[aria-label*="Present"]');
                  if (btn) { btn.click(); return; }
                  // As a fallback, send 'p' key which toggles present in some builds
                  const ev = new KeyboardEvent('keydown', {key: 'p'});
                  document.dispatchEvent(ev);
                })();
                """,
              );
            } catch (_) {
              // Ignore any JS injection error
            }

            // One-time retry to encourage Earth to pick up the deep link/kmlsrc inside WebView
            if (!_didRetry) {
              _didRetry = true;
              await Future.delayed(const Duration(milliseconds: 300));
              try {
                await _controller?.loadRequest(Uri.parse(_earthUrl));
              } catch (_) {}
            }
          },
          onWebResourceError: (error) {
            setState(() {
              _isLoading = false;
              _lastError = error.description;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur Web: ${error.description}')),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_earthUrl));

  }

  Future<void> _initWindowsWebView() async {
    try {
      final c = wvw.WebviewController();
      await c.initialize();
      await c.loadUrl(_earthUrl);
      setState(() {
        _winController = c;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _lastError = 'WebView2 manquant ou erreur d\'initialisation: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('WebView Windows: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: AutoSizeText(
            'Google Earth (Web)',
            maxLines: 1,
            style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              tooltip: 'Retour',
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () async {
                if (Platform.isWindows) {
                  if (_winController != null) {
                    try { await _winController!.goBack(); } catch (_) {}
                  }
                } else {
                  if (_controller != null && await _controller!.canGoBack()) {
                    await _controller!.goBack();
                  }
                }
              },
            ),
            IconButton(
              tooltip: 'Avancer',
              icon: const Icon(Icons.arrow_forward, color: Colors.white),
              onPressed: () async {
                if (Platform.isWindows) {
                  if (_winController != null) {
                    try { await _winController!.goForward(); } catch (_) {}
                  }
                } else {
                  if (_controller != null && await _controller!.canGoForward()) {
                    await _controller!.goForward();
                  }
                }
              },
            ),
            IconButton(
              tooltip: 'Recharger',
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () async {
                if (Platform.isWindows) {
                  if (_winController != null) await _winController!.reload();
                } else {
                  if (_controller != null) await _controller!.reload();
                }
              },
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: Stack(
          children: [
            if (Platform.isWindows)
              if (_winController != null)
                wvw.Webview(_winController!)
              else
                const SizedBox.shrink()
            else
              if (_controller != null)
                WebViewWidget(controller: _controller!)
              else
                const SizedBox.shrink(),
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: Colors.white)),
            if (_lastError != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _lastError!,
                    style: GoogleFonts.montserrat(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: _buildImportHint(),
      ),
    );
  }

  Widget _buildImportHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.black.withOpacity(0.4),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pour charger un KMZ: utilisez le menu de Google Earth (Projets → Importer), ou glissez-déposez votre fichier KMZ dans la page.',
              style: GoogleFonts.montserrat(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

