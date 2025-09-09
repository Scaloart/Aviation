import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:brie_fly/services/firestore_service.dart';
import 'package:brie_fly/models/app_user.dart';
import 'package:brie_fly/screens/home_screen.dart';
import 'package:brie_fly/screens/account_screen.dart';
import 'package:brie_fly/auth_wrapper.dart';
import 'package:brie_fly/widgets/app_window_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:brie_fly/services/bookmarks_service.dart';
import 'package:brie_fly/services/exam_storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  int _statusIndex = 0;
  final List<String> _statusMessages = [
    "Initializing Systems...",
    "Loading Database...",
    "Preparing Flight Modules...",
    "Almost Ready...",
  ];
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    // Subtle breathing animation for logo
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);
    _logoScale = Tween<double>(begin: 0.98, end: 1.02)
        .animate(CurvedAnimation(parent: _logoController, curve: Curves.easeInOut));

    // Rotate through status messages
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 2));
      if (!_isActive || !mounted) return false;
      if (_statusIndex < _statusMessages.length - 1) {
        if (!mounted) return false;
        setState(() => _statusIndex++);
        return true;
      }
      return false;
    });

    // Begin auth and user data preparation during splash and navigate when ready.
    _routeAfterSplash();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _isActive = false;
    super.dispose();
  }

  Future<void> _routeAfterSplash() async {
    // Ensure the welcome page stays visible for 8 seconds
    final minDisplay = Future.delayed(const Duration(seconds: 8));

    // Wait for an authenticated user if one is coming soon (e.g., silent login)
    // We wait up to 6 seconds; if still null, proceed normally.
    User? user;
    try {
      user = await FirebaseAuth.instance
          .idTokenChanges()
          .firstWhere((u) => u != null)
          .timeout(const Duration(milliseconds: 300));
    } catch (_) {
      user = null;
    }

    // Skip heavy sync on splash to minimize duration; do it after navigation instead
    Future<void> syncFuture = Future.value();

    // Wait for both the min splash display and sync to complete
    await Future.wait([minDisplay, syncFuture]);
    if (!mounted) return;
    // Route via AuthWrapper (no animation, dark to avoid white flash)
    // ignore: avoid_print
    print('[Splash] Navigating to AuthWrapper');
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const AuthWrapper(),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      opaque: true,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    final size = MediaQuery.of(context).size;
    final bool isPhone = !isDesktop && size.width < 600;
    final double logoHeight = isPhone
        ? (size.height * 0.18).clamp(96.0, 160.0)
        : 180.0;
    final double titleFontSize = isPhone
        ? (size.width < 360 ? 26 : 32)
        : 40;
    final double progressFont = isPhone ? 13 : 14;
    final double statusFont = isPhone ? 12 : 13;
    final EdgeInsets bottomPad = EdgeInsets.symmetric(horizontal: isPhone ? 20 : 64);
    final double hPad = isPhone ? 20 : 64;
    final double vPad = isPhone ? 12 : 16;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: Colors.black),
        child: Stack(
          children: [
            // Main centered content (below custom bar)
            Padding(
              padding: EdgeInsets.only(top: isDesktop ? AppWindowBar.height : 0),
              child: SafeArea(
                top: !isDesktop, // desktop already offset by window bar
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(vertical: isPhone ? 16 : 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo
                        Image.asset(
                          'assets/logo.png',
                          height: logoHeight,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.flight_takeoff,
                            size: logoHeight * 0.7,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        SizedBox(height: isPhone ? 12 : 16),

                        // App brand/title
                        Text(
                          "Briefly",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.orbitron(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: isPhone ? 8 : 12),

                        // Tagline / credit (only name links to Instagram)
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.center,
                          children: [
                            Text(
                              "Made with ❤️ by ",
                              style: GoogleFonts.roboto(
                                fontSize: progressFont,
                                color: Colors.grey[300],
                              ),
                            ),
                            InkWell(
                              onTap: () async {
                                final Uri url = Uri.parse('https://www.instagram.com/nassihsalah');
                                try {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                } catch (_) {}
                              },
                              child: Text(
                                "NASSIH SALAHEDDINE",
                                style: GoogleFonts.roboto(
                                  fontSize: progressFont,
                                  color: Colors.grey[300],
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Add space so bottom bar does not overlap centered content
                        SizedBox(height: isPhone ? 96 : 120),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom progress section pinned to bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 0, hPad, vPad),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Initializing Briefly. Please wait...",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.roboto(
                          fontSize: progressFont,
                          color: Colors.grey[200],
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.grey[800],
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF1744)),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Status: ${_statusMessages[_statusIndex]}",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.robotoMono(
                          fontSize: statusFont,
                          color: Colors.grey[300],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Overlay custom window bar
            if (isDesktop)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AppWindowBar(),
              ),
          ],
        ),
      ),
    );
  }
}


