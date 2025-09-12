import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:brie_fly/models/dossier_info.dart';
import 'package:brie_fly/auth_wrapper.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'screens/dossiers_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'routes.dart';

import 'models/airport_model.dart';
import 'services/database_service.dart';
import 'services/navigation_service.dart';
import 'temsi_config_screen.dart';
import 'wintem_config_screen.dart';
import 'notam_config_screen.dart';
import 'flight_plan_screen.dart';
import 'weight_balance_screen.dart';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'dart:io';
import 'package:brie_fly/services/qcm_question_service.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brie_fly/services/auth_service.dart';
import 'package:brie_fly/models/app_user.dart';
import 'package:brie_fly/services/purchase_service.dart';
import 'package:brie_fly/services/firestore_service.dart';
import 'package:brie_fly/services/theme_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:brie_fly/screens/Welcome.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/update_service.dart';
import 'services/navigation_service.dart';

// TODO: Add your RevenueCat API keys here
const revenueCatApiKey = 'goog_YOUR_REVENUECAT_API_KEY';

Future<void> _initLogging() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final logs = Directory('${dir.path}/logs');
    if (!await logs.exists()) {
      await logs.create(recursive: true);
    }
  } catch (_) {}
}

Future<void> _logError(Object error, StackTrace? stack, {String? context}) async {
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/logs/app.log');
    final now = DateTime.now().toIso8601String();
    final lines = [
      '=== ERROR $now ${context ?? ''} ===',
      error.toString(),
      if (stack != null) stack.toString(),
      '\n'
    ];
    await file.writeAsString(lines.join('\n'), mode: FileMode.append, flush: true);
  } catch (_) {}
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize logging directory early
    await _initLogging();

    // Capture Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) async {
      FlutterError.dumpErrorToConsole(details);
      await _logError(details.exception, details.stack, context: 'FlutterError');
    };

    // Initialize FFI for desktop
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // Initialize FFI for web
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    }

    // Make status bar blend with app background on mobile
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ));
    }

    // Ensure window_manager is initialized for desktop (needed for fullscreen)
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        await windowManager.ensureInitialized();
      } catch (e, s) {
        await _logError(e, s, context: 'windowManager.ensureInitialized');
      }
      const windowOptions = WindowOptions(
        // Use native title bar on macOS so close/minimize/fullscreen buttons are visible
        titleBarStyle: TitleBarStyle.normal,
        windowButtonVisibility: true,
      );
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        try {
          // Explicitly exit fullscreen on macOS before showing the window
          if (Platform.isMacOS) {
            try { await windowManager.setFullScreen(false); } catch (_) {}
            try { await windowManager.setResizable(true); } catch (_) {}
            try { await windowManager.setMinimumSize(const Size(1024, 700)); } catch (_) {}
            try { await windowManager.setSize(const Size(1280, 800)); } catch (_) {}
            try { await windowManager.center(); } catch (_) {}
          }
          await windowManager.show();
          await windowManager.focus();
        } catch (e, s) {
          await _logError(e, s, context: 'windowManager.show/focus');
        }
        await Future.delayed(const Duration(milliseconds: 150));
        try {
          // Do not force fullscreen on macOS; just maximize. Keep fullscreen for others.
          if (Platform.isMacOS) {
            // Keep windowed mode with native title bar
            await windowManager.setFullScreen(false);
          } else {
            await windowManager.setFullScreen(true);
          }
        } catch (e1, s1) {
          await _logError(e1, s1, context: 'windowManager.setFullScreen');
          try {
            await windowManager.maximize();
          } catch (e2, s2) {
            await _logError(e2, s2, context: 'windowManager.maximize');
          }
        }
      });
    }

    // Do not await Firebase init here to avoid delaying first UI frame.

    // Defer non-critical purchase init until after first frame to avoid delaying first UI
    try {
      PurchaseService.setApiKey(revenueCatApiKey);
      // Initialize later (post-frame) to not block first frame
    } catch (e, s) {
      await _logError(e, s, context: 'PurchaseService.setApiKey');
    }

    // Touch FA to ensure fonts are included
    FaIcon(FontAwesomeIcons.plane);

    runApp(const Epl3TheBriefApp());

    // Re-apply fullscreen right after first frame (helps on hot restart)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initialize purchases after first frame
      try {
        await PurchaseService().init();
      } catch (e, s) {
        await _logError(e, s, context: 'PurchaseService.init (post-frame)');
      }

      // Desktop window tweaks after first frame
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        await Future.delayed(const Duration(milliseconds: 150));
        try {
          if (Platform.isMacOS) {
            await windowManager.setFullScreen(false);
            await windowManager.focus();
          } else {
            await windowManager.setFullScreen(true);
            await windowManager.focus();
          }
        } catch (e, s) {
          await _logError(e, s, context: 'postFrame fullscreen/focus');
        }
      }
    });
  }, (error, stack) async {
    await _logError(error, stack, context: 'Zone');
  });
}

class Epl3TheBriefApp extends StatefulWidget {
  const Epl3TheBriefApp({super.key});

  @override
  State<Epl3TheBriefApp> createState() => _Epl3TheBriefAppState();
}

class _Epl3TheBriefAppState extends State<Epl3TheBriefApp> {
  // Create ThemeService early (doesn't depend on Firebase)
  late final ThemeService _themeService;
  // Defer AuthService until after Firebase.init to avoid [core/no-app]
  AuthService? _authService;
  Key _key = UniqueKey();
  bool _adsInitialized = false;
  bool _updateChecked = false;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService();
  }

  void _refreshApp() {
    // No-op: avoid resetting MaterialApp/Navigator which would show SplashScreen again.
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.dark,
            theme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.black,
            ),
            home: const Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: Text('Init error', style: TextStyle(color: Colors.white))),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          // Show immediate frame with app background
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.dark,
            theme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.black,
            ),
            home: const Scaffold(backgroundColor: Colors.black),
          );
        }
        // Ensure AuthService is created only after Firebase is initialized
        _authService ??= AuthService(
          onAuthChanged: _refreshApp,
          themeService: _themeService,
        );

        // Schedule a one-time mandatory update check after first frame when Firebase is ready
        if (!_updateChecked) {
          _updateChecked = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await UpdateService.checkForMandatoryUpdate(context);
          });
        }

        // Initialize Google Mobile Ads once (mobile only)
        if (!_adsInitialized && !kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          try {
            MobileAds.instance.initialize();
          } catch (_) {}
          _adsInitialized = true;
        }

        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: _themeService), // Use the instance
            Provider<AuthService>.value(value: _authService!),
            Provider<PurchaseService>(create: (_) => PurchaseService()),
            Provider<FirestoreService>(create: (_) => FirestoreService()),
          ],
          child: MaterialApp(
            key: _key, // Kept stable so Navigator state is preserved across auth changes
            debugShowCheckedModeBanner: false,
            navigatorKey: NavigationService.rootNavigatorKey,
            title: 'Dossier de Vol',
            themeMode: ThemeMode.dark,
            theme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.black,
              visualDensity: VisualDensity.adaptivePlatformDensity,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                surfaceTintColor: Colors.transparent,
                iconTheme: IconThemeData(color: Colors.white),
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFFF1744),
                brightness: Brightness.dark,
              ),
              progressIndicatorTheme: const ProgressIndicatorThemeData(color: Color(0xFFFF1744)),
              pageTransitionsTheme: const PageTransitionsTheme(builders: {
                TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
              }),
            ),
            navigatorObservers: [routeObserver],
            home: const SplashScreen(),
          ),
        );
      },
    );
  }
}


