import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as winwv;

class ProofPreviewScreen extends StatefulWidget {
  final String url;
  final String? title;
  const ProofPreviewScreen({super.key, required this.url, this.title});

  @override
  State<ProofPreviewScreen> createState() => _ProofPreviewScreenState();
}

class _ProofPreviewScreenState extends State<ProofPreviewScreen> {
  winwv.WebviewController? _winController;

  bool get _isPdf => widget.url.toLowerCase().contains('.pdf');
  bool get _isWindows => !kIsWeb && Platform.isWindows;
  String get _gdocUrl => 'https://docs.google.com/gview?embedded=1&url=' + Uri.encodeComponent(widget.url);

  @override
  void initState() {
    super.initState();
    if (_isPdf && _isWindows) {
      _initWindowsWebview();
    }
  }

  Future<void> _initWindowsWebview() async {
    final controller = winwv.WebviewController();
    await controller.initialize();
    await controller.setBackgroundColor(Colors.transparent);
    await controller.loadUrl(_gdocUrl);
    if (mounted) setState(() => _winController = controller);
  }

  @override
  void dispose() {
    _winController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? 'Aperçu de la preuve')),
      body: _isPdf
          ? (_isWindows
              ? (_winController == null
                  ? const Center(child: CircularProgressIndicator())
                  : winwv.Webview(_winController!))
              : _MobilePdfWebView(url: _gdocUrl))
          : InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  widget.url,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Impossible d\'afficher l\'image.\n$e'),
                  ),
                ),
              ),
            ),
    );
  }
}

class _MobilePdfWebView extends StatefulWidget {
  final String url;
  const _MobilePdfWebView({required this.url});

  @override
  State<_MobilePdfWebView> createState() => _MobilePdfWebViewState();
}

class _MobilePdfWebViewState extends State<_MobilePdfWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
