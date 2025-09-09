import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

class PaypalWebViewScreen extends StatefulWidget {
  final String approvalUrl;
  final String successUrl; // When PayPal redirects here, we consider flow done
  final String cancelUrl; // When PayPal redirects here, we consider flow cancelled

  const PaypalWebViewScreen({
    super.key,
    required this.approvalUrl,
    required this.successUrl,
    required this.cancelUrl,
  });

  @override
  State<PaypalWebViewScreen> createState() => _PaypalWebViewScreenState();
}

class _PaypalWebViewScreenState extends State<PaypalWebViewScreen> {
  late final WebviewController _controller;
  bool _initialized = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebviewController();
    _init();
  }

  Future<void> _init() async {
    await _controller.initialize();

    // Listen for URL changes to detect success/cancel redirects
    _controller.url.listen((url) {
      if (!mounted) return;
      if (url.startsWith(widget.successUrl)) {
        Navigator.of(context).pop(true);
      } else if (url.startsWith(widget.cancelUrl)) {
        Navigator.of(context).pop(false);
      }
    });

    _controller.loadingState.listen((state) {
      if (!mounted) return;
      setState(() {
        _loading = state == LoadingState.loading;
      });
    });

    // Ensure PayPal popups/new windows open in the same view by overriding window.open
    // Some PayPal flows attempt to open a new window; this keeps navigation in place.
    try {
      await _controller.executeScript("window.open = (u)=>{ window.location.href = u; };");
    } catch (_) {}

    await _controller.loadUrl(widget.approvalUrl);
    if (!mounted) return;
    setState(() {
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Paiement PayPal',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Webview(_controller,
                    permissionRequested: (url, kind, isUserInitiated) async {
                  // Allow all permissions for checkout flow
                  return WebviewPermissionDecision.allow;
                }),
                // White overlay to hide the web content beneath the transparent AppBar area
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: kToolbarHeight + MediaQuery.of(context).padding.top,
                    color: Colors.white,
                  ),
                ),
                if (_loading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
    );
  }
}
