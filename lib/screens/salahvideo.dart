// ignore_for_file: library_prefixes
import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart'; // For LogicalKeyboardKey
import 'package:video_player/video_player.dart' as video_player; // standard video_player
import 'package:http/http.dart' as http;
import 'package:window_manager/window_manager.dart';
import 'package:brie_fly/widgets/app_window_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:brie_fly/services/ads/interstitial_ad_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Must add this line.
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    center: true,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProVideoApp());
}

// ===================== Painters =====================

class _CountdownRingPainter extends CustomPainter {
  final double progress; // 0..1
  final double strokeWidth;
  final Gradient gradient;
  final Color trackColor;

  _CountdownRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.gradient,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // Track circle
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc with gradient
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(rect);

    final startAngle = -math.pi / 2; // start at top
    final sweepAngle = (2 * math.pi) * progress.clamp(0.0, 1.0);
    canvas.drawArc(rect, startAngle, sweepAngle, false, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _CountdownRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.gradient != gradient;
  }
}

class _PrimaryPlayButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPressed;
  const _PrimaryPlayButton({required this.isPlaying, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 6,
          shadowColor: Colors.black54,
          padding: EdgeInsets.zero,
        ),
        onPressed: onPressed,
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 36,
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  final IconData icon;
  final String label; // e.g., -10 / +10
  final String? tooltip;
  final VoidCallback onPressed;
  const _SkipButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = FilledButton.tonal(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.08),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
    return tooltip == null
        ? btn
        : Tooltip(message: tooltip!, child: btn);
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  const _NavButton({required this.icon, required this.label, required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final btn = FilledButton.tonal(
      style: FilledButton.styleFrom(
        backgroundColor: enabled ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.04),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      onPressed: enabled ? onPressed : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
    return btn;
  }
}

class ProVideoApp extends StatelessWidget {
  const ProVideoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF49A6FF),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EPL3 Pro Player',
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF0E1117),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(letterSpacing: 0.2),
        ),
      ),
      home: const PlayerShell(),
    );
  }
}

class PlayerShell extends StatefulWidget {
  final String? videoUrl;
  final String? videoTitle;
  final List<String>? playlistUrls;
  final List<String>? playlistTitles;
  final int? initialIndex;
  // Optional thumbnails for current video and playlist items (same ordering as playlistUrls)
  final String? videoThumbnail;
  final List<String>? playlistThumbnails;
  const PlayerShell({Key? key, this.videoUrl, this.videoTitle, this.playlistUrls, this.playlistTitles, this.initialIndex, this.videoThumbnail, this.playlistThumbnails}) : super(key: key);
  @override
  State<PlayerShell> createState() => _PlayerShellState();
}

class _PlayerShellState extends State<PlayerShell> {
  // Playlist state
  List<String>? _playlistUrls;
  List<String>? _playlistTitles;
  int? _playlistIndex;
  List<String>? _playlistThumbs;
  String? _videoThumb;
  @override
  void initState() {
    super.initState();
    // On mobile, open the player page in landscape by default
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // Don't hide system UI here; just lock orientation to landscape
      SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
      );
      // Enforce fullscreen on mobile for the entire player session
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _applyMobileFullScreen(true);
        if (mounted) {
          setState(() => _isFullScreen = true);
        }
        // Load and show an interstitial at video open (mobile only)
        await InterstitialAdService.loadIfNeeded();
        // Force the first ad on video open if available
        await InterstitialAdService.showIfAvailable(force: true);
        // After ad attempt, start initial video if provided
        if (mounted && widget.videoUrl != null) {
          await _loadControllerFromUrl(widget.videoUrl!);
          if (mounted) {
            setState(() {
              _currentSourceLabel = widget.videoUrl;
            });
          }
        }
      });
    }
    // Capture playlist data
    _playlistUrls = widget.playlistUrls;
    _playlistTitles = widget.playlistTitles;
    _playlistIndex = widget.initialIndex;
    _playlistThumbs = widget.playlistThumbnails;
    _videoThumb = widget.videoThumbnail;
    // On desktop/web, start immediately; on mobile we start after ad above
    if (widget.videoUrl != null && (kIsWeb || !(Platform.isAndroid || Platform.isIOS))) {
      Future.microtask(() async {
        await _loadControllerFromUrl(widget.videoUrl!);
        if (mounted) {
          setState(() {
            _currentSourceLabel = widget.videoUrl;
          });
        }
      });
    }
    // Ensure hidden title bar when not fullscreen; defer fullscreen until video ready
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await windowManager.setTitleBarStyle(
          TitleBarStyle.hidden,
          windowButtonVisibility: false,
        );
      } catch (_) {}
    });
  }
  video_player.VideoPlayerController? _controller;
  bool _isFullScreen = false;
  bool _wasAlwaysOnTop = false;
  double _savedVolume = 0.7;
  String? _currentSourceLabel; // file name or URL label
  bool _autoFullscreenDesktop = true; // request fullscreen after first successful init on desktop
  // autoplay next handling
  bool _autoAdvanced = false;
  VoidCallback? _completionListener;
  // countdown to next
  bool _pendingAdvance = false;
  int _advanceRemaining = 0; // seconds
  Timer? _advanceTimer;
  int _advanceTotalSeconds = 6;
  // smooth progress animation for ring
  Timer? _advanceAnimTimer;
  double _advanceProgress = 0.0; // 0..1

  // initialization guard/fallback
  bool _initFailed = false;
  String? _lastTriedUrl;
  Timer? _softInitTimer;
  final Set<String> _triedUrls = <String>{};
  

  // overlay
  bool _showControls = true;
  Timer? _overlayTimer;
  final _overlayHideDelay = const Duration(seconds: 3);

  // Mobile YouTube-style UI state
  bool _showRemainingNegative = true; // tap to toggle remaining/total
  bool _flashLeft = false;
  bool _flashRight = false;
  Timer? _flashLeftTimer;
  Timer? _flashRightTimer;

  // speeds menu
  final List<double> _speeds = const [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2.0];
  double _currentSpeed = 1.0;


  // ---------- Playlist navigation ----------
  String? get _currentTitle {
    if (_playlistTitles != null && _playlistIndex != null &&
        _playlistIndex! >= 0 && _playlistIndex! < _playlistTitles!.length) {
      return _playlistTitles![_playlistIndex!];
    }
    return widget.videoTitle ?? _currentSourceLabel;
  }

  // For wrap-around UX, keep buttons enabled when a playlist exists
  bool get _hasPrev => _playlistUrls != null && _playlistUrls!.isNotEmpty;
  bool get _hasNext => _playlistUrls != null && _playlistUrls!.isNotEmpty;

  Future<void> _playFromPlaylistIndex(int idx) async {
    if (_playlistUrls == null) return;
    if (_playlistUrls!.isEmpty) return;
    // Wrap index
    final len = _playlistUrls!.length;
    idx = ((idx % len) + len) % len;
    final url = _playlistUrls![idx];
    await _loadControllerFromUrl(url);
    setState(() {
      _playlistIndex = idx;
      _currentSourceLabel = url;
    });
  }

  Future<void> _playPrevInPlaylist() async {
    if (_playlistUrls == null || _playlistUrls!.isEmpty) return;
    final current = _playlistIndex ?? 0;
    await _playFromPlaylistIndex(current - 1);
  }

  Future<void> _playNextInPlaylist() async {
    if (_playlistUrls == null || _playlistUrls!.isEmpty) return;
    final current = _playlistIndex ?? 0;
    await _playFromPlaylistIndex(current + 1);
  }

  Future<void> _autoPlayNextWrap() async {
    if (_playlistUrls == null || _playlistUrls!.isEmpty) return;
    final current = _playlistIndex ?? 0;
    await _playFromPlaylistIndex(current + 1);
  }

  String _nextLabel() {
    if (_playlistUrls == null || _playlistUrls!.isEmpty) return 'Next';
    final len = _playlistUrls!.length;
    final nextIdx = (((_playlistIndex ?? 0) + 1) % len + len) % len;
    if (_playlistTitles != null && nextIdx >= 0 && nextIdx < _playlistTitles!.length) {
      return _playlistTitles![nextIdx];
    }
    final url = _playlistUrls![nextIdx];
    // If URL, show last path segment as a label
    final uri = Uri.tryParse(url);
    final seg = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : url;
    return seg;
  }

  String? _nextThumbUrl() {
    if (_playlistUrls == null || _playlistUrls!.isEmpty) return null;
    if (_playlistThumbs == null || _playlistThumbs!.isEmpty) return null;
    final len = _playlistUrls!.length;
    final nextIdx = (((_playlistIndex ?? 0) + 1) % len + len) % len;
    if (nextIdx >= 0 && nextIdx < _playlistThumbs!.length) {
      final t = _playlistThumbs![nextIdx];
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  // ------- Subtitles -------
  List<_SubtitleCue> _subtitles = [];
  String? _subtitleUrl;
  double _subtitleFont = 18;
  bool get _subtitlesEnabled => _subtitles.isNotEmpty;

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _advanceTimer?.cancel();
    _advanceAnimTimer?.cancel();
    _softInitTimer?.cancel();
    _detachCompletionListener(_controller);
    _controller?.dispose();
    // Ensure mobile UI/orientation are restored if we exit while fullscreen
    _applyMobileFullScreen(false);
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // Restore system-wide orientation preferences for the rest of the app
      try {
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      } catch (_) {}
    }
    super.dispose();
  }

  // ---------- Source loading ----------
  bool _isLikelyUnsupported(String url) {
    final u = url.toLowerCase();
    return u.endsWith('.avi') || u.endsWith('.wmv') || u.endsWith('.mkv');
  }
  bool _isMp4(String url) => url.toLowerCase().endsWith('.mp4');
  Future<void> _openNetworkUrlDialog() async {
    final res = await showDialog<_UrlDialogResult>(
      context: context,
      builder: (context) => const _OpenUrlDialog(),
    );
    if (res == null || res.url.isEmpty) return;

    await _loadControllerFromUrl(res.url);
    setState(() {
      _currentSourceLabel = res.url;
    });
  }

  // Quality management removed; desktop player shows no quality UI.

  Future<void> _loadControllerFromUrl(String url) async {
    final old = _controller;
    final next = video_player.VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: video_player.VideoPlayerOptions(
        mixWithOthers: true,
      ),
    );
    _controller = next;
    _initFailed = false;
    _lastTriedUrl = url;
    _triedUrls.add(url);
    // Cancel any prior timers and decide immediate vs soft overlay
    _softInitTimer?.cancel();
    if (_isLikelyUnsupported(url)) {
      // Immediately offer fallback overlay while still initializing in background
      if (mounted) setState(() => _initFailed = true);
    } else if (_isMp4(url)) {
      // For MP4 (progressive), avoid soft overlay; rely on hard timeout only for a cleaner UX
      // No-op here; spinner will show until initialize completes or hard timeout triggers the fallback
    } else {
      // Soft-timeout overlay after 4s while still trying in background
      _softInitTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        if (!(_controller?.value.isInitialized ?? false)) {
          setState(() => _initFailed = true);
        }
      });
    }
    // Kick off initialization without blocking the UI
    _initializePlay(next, old, originalUrl: url);
    // Trigger rebuild so UI can show spinner immediately
    if (mounted) setState(() {});
  }

  Future<void> _initializePlay(
      video_player.VideoPlayerController next,
      video_player.VideoPlayerController? old,
      {required String originalUrl}) async {
    try {
      // If initialization takes too long (e.g., unsupported container like AVI on some phones),
      // fall back instead of spinning forever.
      await next.initialize().timeout(const Duration(seconds: 15));
      await next.setVolume(_savedVolume);
      await next.setLooping(false);
      if (!mounted) return;
      setState(() {
        _currentSpeed = 1.0;
      });
      // cancel soft overlay timer if we got initialized
      _softInitTimer?.cancel();
      // attach completion listener
      _autoAdvanced = false;
      _detachCompletionListener(old);
      _attachCompletionListener(next);
      await next.play();
      // Enter fullscreen after first frame is ready (desktop only)
      if (!mounted) return;
      final bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
      if (isDesktop && _autoFullscreenDesktop && !_isFullScreen) {
        await _enterFullScreen();
        // Only auto-trigger once per app session
        _autoFullscreenDesktop = false;
      }
    } catch (e) {
      // Mark failure and surface a fallback UI
      if (mounted) {
        setState(() {
          _initFailed = true;
        });
      }
      _snack('Failed to open video. Trying external player.');
      // Attempt Archive.org variant swap if applicable and not yet tried
      final alt = _alternateArchiveVariant(originalUrl);
      if (alt != null && !_triedUrls.contains(alt)) {
        _triedUrls.add(alt);
        await old?.dispose();
        await _loadControllerFromUrl(alt);
        return;
      }
    } finally {
      await old?.dispose();
    }
  }

  String? _alternateArchiveVariant(String url) {
    // Swap between .../NN.ia.mp4 and .../NN.mp4 for Archive.org URLs
    try {
      final u = Uri.parse(url);
      if (!u.host.contains('archive.org')) return null;
      final path = u.path;
      if (path.endsWith('.ia.mp4')) {
        final altPath = path.replaceFirst(RegExp(r'\.ia\.mp4\$'), '.mp4');
        return u.replace(path: altPath).toString();
      }
      if (path.endsWith('.mp4') && !path.endsWith('.ia.mp4')) {
        final altPath = path.replaceFirst(RegExp(r'\.mp4\$'), '.ia.mp4');
        return u.replace(path: altPath).toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openExternally() async {
    final url = _lastTriedUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _snack('No app found to open this video.');
    }
  }

  void _attachCompletionListener(video_player.VideoPlayerController c) {
    _completionListener ??= _onControllerTick;
    c.addListener(_completionListener!);
  }

  void _detachCompletionListener(video_player.VideoPlayerController? c) {
    if (c == null) return;
    if (_completionListener != null) {
      try {
        c.removeListener(_completionListener!);
      } catch (_) {}
    }
  }

  void _onControllerTick() {
    final c = _controller;
    if (c == null) return;
    final v = c.value;
    if (!v.isInitialized) return;
    final dur = v.duration;
    if (dur == Duration.zero) return;
    // Consider completed when within 200ms of end and not yet advanced
    final remaining = dur - v.position;
    if (!_autoAdvanced && !_pendingAdvance && remaining.inMilliseconds <= 200) {
      _startAutoAdvanceCountdown(6);
    }
  }

  void _startAutoAdvanceCountdown(int seconds) {
    if (_pendingAdvance) return;
    setState(() {
      _pendingAdvance = true;
      _advanceRemaining = seconds;
      _advanceTotalSeconds = seconds;
      _advanceProgress = 0.0;
    });
    _advanceTimer?.cancel();
    _advanceTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      if (_advanceRemaining <= 1) {
        t.cancel();
        _advanceTimer = null;
        _autoAdvanced = true;
        setState(() {
          _pendingAdvance = false;
          _advanceProgress = 1.0;
        });
        _advanceAnimTimer?.cancel();
        _advanceAnimTimer = null;
        await _autoPlayNextWrap();
        return;
      }
      setState(() {
        _advanceRemaining -= 1;
      });
    });

    // smooth progress 10Hz
    _advanceAnimTimer?.cancel();
    _advanceAnimTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted || !_pendingAdvance) return;
      final elapsedSeconds = (_advanceTotalSeconds - _advanceRemaining);
      // add fractional 0.1 steps
      final fractional = (t.tick % 10) / 10.0;
      final value = ((elapsedSeconds + fractional) / _advanceTotalSeconds).clamp(0.0, 1.0);
      setState(() {
        _advanceProgress = value;
      });
    });
  }

  void _cancelAutoAdvanceCountdown() {
    if (!_pendingAdvance) return;
    _advanceTimer?.cancel();
    _advanceTimer = null;
    _advanceAnimTimer?.cancel();
    _advanceAnimTimer = null;
    setState(() {
      _pendingAdvance = false;
      _advanceRemaining = 0;
      _autoAdvanced = false;
      _advanceProgress = 0.0;
    });
  }

  // ---------- Subtitles ----------
  Future<void> _loadSubtitlesFromUrl(String url) async {
    try {
      final r = await http.get(Uri.parse(url));
      if (r.statusCode != 200) {
        _snack('Failed to fetch subtitles (${r.statusCode}).');
        return;
      }
      final text = r.body;
      final cues = _parseSubtitle(text);
      setState(() {
        _subtitles = cues;
        _subtitleUrl = url;
      });
      _snack('Subtitles loaded.');
    } catch (e) {
      _snack('Failed to load subtitles: $e');
    }
  }

  void _clearSubtitles() {
    setState(() {
      _subtitles = [];
      _subtitleUrl = null;
    });
  }

  _SubtitleCue? _getCurrentSubtitle(Duration position) {
    // Binary search would be faster; linear is fine for typical SRT sizes.
    for (final cue in _subtitles) {
      if (position >= cue.start && position <= cue.end) return cue;
    }
    return null;
  }

  // ---------- UI helpers ----------
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
  }

  void _toggleMute() async {
    final c = _controller;
    if (c == null) return;
    final vol = c.value.volume;
    if (vol > 0) {
      _savedVolume = vol;
      await c.setVolume(0);
    } else {
      await c.setVolume(_savedVolume == 0 ? 0.5 : _savedVolume);
    }
    setState(() {});
  }

  void _seekBy(Duration delta) {
    final c = _controller;
    if (c == null) return;
    final pos = c.value.position + delta;
    final clampedPosMilliseconds = pos.inMilliseconds.clamp(
      0,
      c.value.duration.inMilliseconds,
    );
    c.seekTo(Duration(milliseconds: clampedPosMilliseconds));
  }

  void _onDoubleTapLeft() {
    _seekBy(const Duration(seconds: -10));
    setState(() => _flashLeft = true);
    _flashLeftTimer?.cancel();
    _flashLeftTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _flashLeft = false);
    });
    _showNowAndAutoHide();
  }

  void _onDoubleTapRight() {
    _seekBy(const Duration(seconds: 10));
    setState(() => _flashRight = true);
    _flashRightTimer?.cancel();
    _flashRightTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _flashRight = false);
    });
    _showNowAndAutoHide();
  }

  String _fmtTime(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // --- Mobile fullscreen helpers (Android/iOS) ---
  Future<void> _applyMobileFullScreen(bool enable) async {
    if (kIsWeb) return;
    final isMobile = Platform.isAndroid || Platform.isIOS;
    if (!isMobile) return;
    try {
      if (enable) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    } catch (_) {}
  }

  Future<void> _enterFullScreen() async {
    if (_isFullScreen) return;
    setState(() => _isFullScreen = true);
    final bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    if (isDesktop) {
      try {
        try {
          _wasAlwaysOnTop = await windowManager.isAlwaysOnTop();
        } catch (_) {}
        try { await windowManager.setResizable(false); } catch (_) {}
        await windowManager.setFullScreen(true);
        try {
          await windowManager.setTitleBarStyle(
            TitleBarStyle.hidden,
            windowButtonVisibility: false,
          );
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 80));
        try {
          final ok = await windowManager.isFullScreen();
          if (!ok) {
            await windowManager.setFullScreen(true);
          }
        } catch (_) {}
        try { await windowManager.setAlwaysOnTop(true); } catch (_) {}
        await windowManager.focus();
      } catch (_) {
        await windowManager.maximize();
      }
    } else {
      // Mobile: hide system UI and force landscape
      await _applyMobileFullScreen(true);
    }
    _showNowAndAutoHide();
  }

  Future<void> _exitFullScreen() async {
    if (!_isFullScreen) return;
    setState(() => _isFullScreen = false);
    final bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    if (isDesktop) {
      try {
        await windowManager.setFullScreen(false);
        try {
          await windowManager.setTitleBarStyle(
            TitleBarStyle.hidden,
            windowButtonVisibility: false,
          );
        } catch (_) {}
        try { await windowManager.setAlwaysOnTop(_wasAlwaysOnTop); } catch (_) {}
        try { await windowManager.setResizable(true); } catch (_) {}
      } catch (_) {
        await windowManager.unmaximize();
      }
    } else {
      // Mobile: restore system UI and orientation
      await _applyMobileFullScreen(false);
    }
    _showNowAndAutoHide();
  }

  Future<void> _toggleFullScreen() async {
    // On mobile, fullscreen is enforced; do nothing
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) return;
    if (_isFullScreen) {
      await _exitFullScreen();
    } else {
      await _enterFullScreen();
    }
  }

  void _setSpeed(double v) async {
    final c = _controller;
    if (c == null) return;
    await c.setPlaybackSpeed(v);
    setState(() => _currentSpeed = v);
  }

  void _onPointerMove() {
    _showNowAndAutoHide();
  }

  void _showNowAndAutoHide() {
    setState(() => _showControls = true);
    _overlayTimer?.cancel();
    _overlayTimer = Timer(_overlayHideDelay, () {
      if (!mounted) return;
      setState(() => _showControls = false);
    });
  }

  // ---------- Shortcuts ----------
  Map<ShortcutActivator, Intent> get _shortcuts => {
        LogicalKeySet(LogicalKeyboardKey.space): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyK): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _SeekLeftIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyJ): const _SeekLeftIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const _SeekRightIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyL): const _SeekRightIntent(),
        // F enters fullscreen only; Esc exits fullscreen only
        LogicalKeySet(LogicalKeyboardKey.keyF): const _EnterFullScreenIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const _ExitFullScreenIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyM): const _MuteIntent(),
        LogicalKeySet(LogicalKeyboardKey.equal): const _SpeedUpIntent(),
        LogicalKeySet(LogicalKeyboardKey.minus): const _SpeedDownIntent(),
      };

  Map<Type, Action<Intent>> get _actions => {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          _togglePlay();
          _showNowAndAutoHide();
          return null;
        }),
        _SeekLeftIntent: CallbackAction<_SeekLeftIntent>(onInvoke: (_) {
          _seekBy(const Duration(seconds: -5));
          _showNowAndAutoHide();
          return null;
        }),
        _SeekRightIntent: CallbackAction<_SeekRightIntent>(onInvoke: (_) {
          _seekBy(const Duration(seconds: 5));
          _showNowAndAutoHide();
          return null;
        }),
        _EnterFullScreenIntent: CallbackAction<_EnterFullScreenIntent>(onInvoke: (_) {
          _enterFullScreen();
          _showNowAndAutoHide();
          return null;
        }),
        _ExitFullScreenIntent: CallbackAction<_ExitFullScreenIntent>(onInvoke: (_) {
          _exitFullScreen();
          _showNowAndAutoHide();
          return null;
        }),
        _MuteIntent: CallbackAction<_MuteIntent>(onInvoke: (_) {
          _toggleMute();
          _showNowAndAutoHide();
          return null;
        }),
        _SpeedUpIntent: CallbackAction<_SpeedUpIntent>(onInvoke: (_) {
          final i = _speeds.indexOf(_currentSpeed);
          final next = (i < _speeds.length - 1) ? _speeds[i + 1] : _speeds[i];
          _setSpeed(next);
          _showNowAndAutoHide();
          return null;
        }),
        _SpeedDownIntent: CallbackAction<_SpeedDownIntent>(onInvoke: (_) {
          final i = _speeds.indexOf(_currentSpeed);
          final prev = (i > 0) ? _speeds[i - 1] : _speeds[i];
          _setSpeed(prev);
          _showNowAndAutoHide();
          return null;
        }),
      };

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final hasVideo = c?.value.isInitialized ?? false;
    final bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    return Shortcuts(
        shortcuts: _shortcuts,
        child: Actions(
          actions: _actions,
          child: Focus(
            autofocus: true,
            child: GestureDetector(
              onTap: _showNowAndAutoHide,
              // On mobile we force fullscreen all the time; disable toggle there
              onDoubleTap: (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS))
                  ? _toggleFullScreen
                  : null,
              onPanDown: (_) => _onPointerMove(),
              onPanUpdate: (_) => _onPointerMove(),
              child: Scaffold(
                extendBodyBehindAppBar: _isFullScreen,
                backgroundColor: Colors.black,
                body: Stack(
                  children: [
                    // --- Gradient background for classy look ---
                    const _Backdrop(),
                    // --- Player area ---
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.zero,
                        child: Builder(builder: (context) {
                          if (hasVideo) {
                            return _VideoSurface(
                              controller: c!,
                              subtitleResolver: _getCurrentSubtitle,
                              subtitleFontSize: _subtitleFont,
                            );
                          }
                          // show spinner if we tried to open something
                          if (_controller != null || _lastTriedUrl != null) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          // initial empty state
                          return _EmptyState(onOpenUrl: _openNetworkUrlDialog);
                        }),
                      ),
                    ),
                    // --- Mobile double-tap seek zones ---
                    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
                      Positioned.fill(
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onDoubleTap: _onDoubleTapLeft,
                                child: Stack(children: [
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: AnimatedOpacity(
                                        opacity: _flashLeft ? 1.0 : 0.0,
                                        duration: const Duration(milliseconds: 150),
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.35),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(Icons.replay_10_rounded, size: 36, color: Colors.white),
                                                SizedBox(width: 6),
                                                Text('-10', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onDoubleTap: _onDoubleTapRight,
                                child: Stack(children: [
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: AnimatedOpacity(
                                        opacity: _flashRight ? 1.0 : 0.0,
                                        duration: const Duration(milliseconds: 150),
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.35),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Text('+10', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                                SizedBox(width: 6),
                                                Icon(Icons.forward_10_rounded, size: 36, color: Colors.white),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // --- Global transparent window bar overlay (desktop only) ---
                    if (isDesktop && !_isFullScreen)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: AppWindowBar(),
                      ),
                    // --- Mobile: top overlay with back + title ---
                    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS) && _showControls)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top + 6,
                            left: 8,
                            right: 8,
                            bottom: 8,
                          ),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black54, Colors.transparent],
                            ),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_rounded),
                                onPressed: () => Navigator.of(context).maybePop(),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _currentTitle ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // --- In-player header (back + title) below the window bar ---
                    if (!_isFullScreen && _showControls)
                      Positioned(
                        left: 12,
                        right: 12,
                        top: AppWindowBar.height + 8,
                        child: _GlassBar(
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () => Navigator.of(context).maybePop(),
                                tooltip: 'Back',
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    _currentTitle ?? 'EPL3 Pro Player',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      letterSpacing: 0.2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                          ),
                        ),
                      ),
                    // --- Bottom controls ---
                    if (hasVideo && _showControls)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        left: 12,
                        right: 12,
                        bottom: MediaQuery.of(context).padding.bottom + 5,
                        child: _GlassBar(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child:
                              ValueListenableBuilder<video_player.VideoPlayerValue>(
                            valueListenable: _controller!,
                            builder: (context, v, _) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // --- Seek bar + timecodes (desktop/tablet only) ---
                                  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS))
                                    _SeekBar(
                                      position: v.position,
                                      duration: v.duration,
                                      onChanged: (p) => _controller!.seekTo(p),
                                    ),
                                  const SizedBox(height: 10),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      // Treat Android/iOS as mobile regardless of width (landscape phones can exceed 520px)
                                      final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
                                      final bool useMobileLayout = isMobile || constraints.maxWidth < 520;

                                      Widget leftSection = LayoutBuilder(
                                        builder: (context, c2) {
                                          final double sliderWidth = c2.maxWidth >= 700
                                              ? 180
                                              : c2.maxWidth >= 520
                                                  ? c2.maxWidth * 0.30
                                                  : c2.maxWidth * 0.24;
                                          return Row(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              // Settings dropdown with submenus
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: MenuAnchor(
                                                  builder: (context, controller, child) {
                                                    return IconButton(
                                                      tooltip: 'Settings',
                                                      onPressed: () {
                                                        if (controller.isOpen) {
                                                          controller.close();
                                                        } else {
                                                          controller.open();
                                                        }
                                                      },
                                                      icon: const Icon(
                                                        Icons.settings_rounded,
                                                        size: 24,
                                                        color: Colors.white,
                                                      ),
                                                      padding: const EdgeInsets.all(6),
                                                      splashRadius: 20,
                                                    );
                                                  },
                                                  menuChildren: [
                                                    MenuItemButton(
                                                      leadingIcon: Icon((v.volume > 0) ? Icons.volume_up_rounded : Icons.volume_off_rounded),
                                                      onPressed: _toggleMute,
                                                      child: Text((v.volume > 0) ? 'Mute' : 'Unmute'),
                                                    ),
                                                    SubmenuButton(
                                                      leadingIcon: const Icon(Icons.volume_down_rounded),
                                                      menuChildren: [
                                                        for (final pct in [25, 50, 75, 100])
                                                          MenuItemButton(
                                                            leadingIcon: ((v.volume * 100).round() == pct)
                                                                ? const Icon(Icons.check, size: 18)
                                                                : const SizedBox(width: 18),
                                                            onPressed: () async {
                                                              final vol = (pct / 100).clamp(0.0, 1.0);
                                                              _savedVolume = vol;
                                                              await _controller!.setVolume(vol);
                                                              setState(() {});
                                                            },
                                                            child: Text('Volume $pct%'),
                                                          ),
                                                      ],
                                                      child: const Text('Volume'),
                                                    ),
                                                    const Divider(height: 1),
                                                    SubmenuButton(
                                                      leadingIcon: const Icon(Icons.speed),
                                                      menuChildren: [
                                                        for (final s in _speeds)
                                                          MenuItemButton(
                                                            leadingIcon: (s == _currentSpeed) ? const Icon(Icons.check, size: 18) : const SizedBox(width: 18),
                                                            onPressed: () => _setSpeed(s),
                                                            child: Text('${s}x'),
                                                          ),
                                                      ],
                                                      child: const Text('Speed'),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              _RoundButton(
                                                icon: (v.volume > 0)
                                                    ? Icons.volume_up_rounded
                                                    : Icons.volume_off_rounded,
                                                onPressed: _toggleMute,
                                              ),
                                              SizedBox(
                                                width: sliderWidth,
                                                child: Slider(
                                                  value: v.volume.clamp(0.0, 1.0),
                                                  onChanged: (val) async {
                                                    _savedVolume = val;
                                                    await _controller!.setVolume(val);
                                                    setState(() {});
                                                  },
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );

                                      Widget centerSection = Wrap(
                                        alignment: WrapAlignment.center,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 10,
                                        runSpacing: 8,
                                        children: [
                                          _NavButton(
                                            icon: Icons.skip_previous_rounded,
                                            label: 'Prev',
                                            enabled: _hasPrev,
                                            onPressed: _playPrevInPlaylist,
                                          ),
                                          _SkipButton(
                                            icon: Icons.replay_10_rounded,
                                            label: '-10',
                                            tooltip: 'Back 10 seconds',
                                            onPressed: () => _seekBy(const Duration(seconds: -10)),
                                          ),
                                          _PrimaryPlayButton(
                                            isPlaying: v.isPlaying,
                                            onPressed: _togglePlay,
                                          ),
                                          _SkipButton(
                                            icon: Icons.forward_10_rounded,
                                            label: '+10',
                                            tooltip: 'Forward 10 seconds',
                                            onPressed: () => _seekBy(const Duration(seconds: 10)),
                                          ),
                                          _NavButton(
                                            icon: Icons.skip_next_rounded,
                                            label: 'Next',
                                            enabled: _hasNext,
                                            onPressed: _playNextInPlaylist,
                                          ),
                                        ],
                                      );

                                      // Restore fullscreen toggle in bottom bar for desktop only
                                      Widget rightSection = (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS))
                                          ? Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                _RoundButton(
                                                  icon: _isFullScreen
                                                      ? Icons.fullscreen_exit_rounded
                                                      : Icons.fullscreen_rounded,
                                                  onPressed: _toggleFullScreen,
                                                ),
                                              ],
                                            )
                                          : const SizedBox.shrink();

                                      if (useMobileLayout) {
                                        // Mobile: YouTube-like single bottom bar
                                        final pos = v.position;
                                        final dur = v.duration;
                                        final totalMs = dur.inMilliseconds;
                                        final value = totalMs > 0 ? (pos.inMilliseconds / totalMs).clamp(0.0, 1.0) : 0.0;
                                        final remaining = dur - pos;
                                        return Row(
                                          children: [
                                            // Prev
                                            IconButton(
                                              icon: const Icon(Icons.skip_previous_rounded),
                                              onPressed: _hasPrev ? _playPrevInPlaylist : null,
                                            ),
                                            IconButton(
                                              icon: Icon(v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                                              onPressed: _togglePlay,
                                            ),
                                            // Next
                                            IconButton(
                                              icon: const Icon(Icons.skip_next_rounded),
                                              onPressed: _hasNext ? _playNextInPlaylist : null,
                                            ),
                                            Text(_fmtTime(pos), style: const TextStyle(fontFeatures: [ui.FontFeature.tabularFigures()])),
                                            const SizedBox(width: 8),
                                            // Seek bar
                                            Expanded(
                                              child: SliderTheme(
                                                data: SliderTheme.of(context).copyWith(
                                                  trackHeight: 3,
                                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                                  overlayShape: SliderComponentShape.noOverlay,
                                                ),
                                                child: Slider(
                                                  value: value,
                                                  onChanged: (nv) {
                                                    // live preview while dragging (optional): we don't change position until end
                                                  },
                                                  onChangeEnd: (nv) {
                                                    final seekMs = (nv * totalMs).round();
                                                    _controller!.seekTo(Duration(milliseconds: seekMs));
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () => setState(() => _showRemainingNegative = !_showRemainingNegative),
                                              child: Text(
                                                _showRemainingNegative ? '-${_fmtTime(remaining.isNegative ? Duration.zero : remaining)}' : _fmtTime(dur),
                                                style: TextStyle(color: Colors.white.withOpacity(0.85), fontFeatures: const [ui.FontFeature.tabularFigures()]),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Volume control (mobile): popover with slider + quick actions
                                            MenuAnchor(
                                              style: const MenuStyle(visualDensity: VisualDensity.compact),
                                              builder: (context, controller, child) => IconButton(
                                                tooltip: 'Volume',
                                                icon: Icon((v.volume > 0) ? Icons.volume_up_rounded : Icons.volume_off_rounded),
                                                onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                                              ),
                                              menuChildren: [
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                                  child: SizedBox(
                                                    width: 220,
                                                    child: Slider(
                                                      value: v.volume.clamp(0.0, 1.0),
                                                      onChanged: (val) async {
                                                        _savedVolume = val;
                                                        await _controller!.setVolume(val);
                                                        setState(() {});
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 4),
                                            // Settings (speed)
                                            MenuAnchor(
                                              style: const MenuStyle(visualDensity: VisualDensity.compact),
                                              builder: (context, controller, child) => IconButton(
                                                icon: const Icon(Icons.settings_rounded),
                                                onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                                              ),
                                              menuChildren: [
                                                SubmenuButton(
                                                  leadingIcon: const Icon(Icons.speed),
                                                  child: const Text('Speed'),
                                                  menuChildren: [
                                                    for (final s in _speeds)
                                                      MenuItemButton(
                                                        leadingIcon: (s == _currentSpeed) ? const Icon(Icons.check, size: 18) : const SizedBox(width: 18),
                                                        onPressed: () => _setSpeed(s),
                                                        child: Text('${s}x'),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        );
                                      } else {
                                        return Row(
                                          children: [
                                            Expanded(child: leftSection),
                                            Expanded(child: centerSection),
                                            Expanded(child: rightSection),
                                          ],
                                        );
                                      }
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    // Up-next countdown overlay (center, with miniature) — polished
                    if (_pendingAdvance)
                      Positioned.fill(
                        child: Stack(
                          children: [
                            // Dimmed scrim with subtle blur
                            Positioned.fill(
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                                child: Container(color: Colors.black.withOpacity(0.35)),
                              ),
                            ),
                            Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 560),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Miniature preview card
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.4),
                                            blurRadius: 18,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            // Thumbnail (16:9). If missing, show gradient placeholder.
                                            Builder(builder: (context) {
                                              final thumb = _nextThumbUrl();
                                              if (thumb != null && thumb.isNotEmpty) {
                                                return AspectRatio(
                                                  aspectRatio: 16 / 9,
                                                  child: Image.network(
                                                    thumb,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (c, e, s) {
                                                      return Container(
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            begin: Alignment.topLeft,
                                                            end: Alignment.bottomRight,
                                                            colors: [
                                                              Colors.blueGrey.shade800.withOpacity(0.95),
                                                              Colors.black.withOpacity(0.95),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                );
                                              }
                                              return AspectRatio(
                                                aspectRatio: 16 / 9,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                      colors: [
                                                        Colors.blueGrey.shade800.withOpacity(0.95),
                                                        Colors.black.withOpacity(0.95),
                                                      ],
                                                    ),
                                                  ),
                                                  child: Center(
                                                    child: Icon(
                                                      Icons.play_circle_fill_rounded,
                                                      size: 84,
                                                      color: Colors.white.withOpacity(0.9),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),
                                            // Circular gradient countdown overlay
                                            Positioned(
                                              right: 14,
                                              top: 14,
                                              child: SizedBox(
                                                width: 64,
                                                height: 64,
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    // subtle base circle
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: Colors.black.withOpacity(0.35),
                                                      ),
                                                    ),
                                                    CustomPaint(
                                                      size: const Size(64, 64),
                                                      painter: _CountdownRingPainter(
                                                        progress: _advanceProgress,
                                                        trackColor: Colors.white.withOpacity(0.18),
                                                        gradient: const SweepGradient(
                                                          colors: [
                                                            Color(0xFF66E0FF),
                                                            Color(0xFF6AFFB2),
                                                            Color(0xFF66E0FF),
                                                          ],
                                                        ),
                                                        strokeWidth: 6,
                                                      ),
                                                    ),
                                                    Text(
                                                      '$_advanceRemaining',
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    // Title and actions
                                    _GlassBar(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            _nextLabel(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: _cancelAutoAdvanceCountdown,
                                                  icon: const Icon(Icons.close_rounded),
                                                  label: const Text('Cancel'),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: FilledButton.icon(
                                                  onPressed: () async {
                                                    _advanceTimer?.cancel();
                                                    _advanceTimer = null;
                                                    _advanceAnimTimer?.cancel();
                                                    _advanceAnimTimer = null;
                                                    setState(() {
                                                      _pendingAdvance = false;
                                                      _autoAdvanced = true;
                                                      _advanceProgress = 1.0;
                                                    });
                                                    await _autoPlayNextWrap();
                                                  },
                                                  icon: const Icon(Icons.play_arrow_rounded),
                                                  label: const Text('Play now'),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Removed floating fullscreen overlay button
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }
}

// ===================== Widgets ======================

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    // Layered gradients for a premium look.
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0E1117), Color(0xFF101826)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        Align(
          alignment: Alignment.topRight,
          child: Container(
            margin: const EdgeInsets.only(top: 60, right: 60),
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.blue.withOpacity(0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 60, left: 60),
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.purple.withOpacity(0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _VideoSurface extends StatelessWidget {
  final video_player.VideoPlayerController controller;
  final _SubtitleCue? Function(Duration) subtitleResolver;
  final double subtitleFontSize;

  const _VideoSurface({
    required this.controller,
    required this.subtitleResolver,
    required this.subtitleFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<video_player.VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, v, _) {
        if (!v.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }
        final ar = v.aspectRatio > 0 ? v.aspectRatio : 16 / 9;
        final cue = subtitleResolver(v.position);

        return ColoredBox(
          color: Colors.black,
          child: Center(
            child: AspectRatio(
              aspectRatio: ar,
              child: Stack(
                children: [
                  video_player.VideoPlayer(controller),
                  if (cue != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          alignment: Alignment.bottomCenter,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: Text(
                                cue.text,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: subtitleFontSize,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600,
                                  shadows: const [
                                    Shadow(
                                      blurRadius: 4,
                                      color: Colors.black,
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlassBar extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _GlassBar({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _RoundButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.08),
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(10),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 24, color: Colors.white),
    );
  }
}

class _IconBtnSmall extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _IconBtnSmall({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null;
    return IconButton.filledTonal(
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(disabled ? 0.04 : 0.08),
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(8),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 20,
        color: Colors.white.withOpacity(disabled ? 0.5 : 1.0),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onChanged;
  const _SeekBar({
    required this.position,
    required this.duration,
    required this.onChanged,
  });

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _draggingNormalizedValue; // Store normalized value 0.0 - 1.0

  @override
  Widget build(BuildContext context) {
    // Ensure duration is never zero to avoid division by zero or invalid ranges.
    final totalMilliseconds = widget.duration.inMilliseconds;
    final currentPositionMilliseconds = widget.position.inMilliseconds;

    // Calculate normalized value for current position
    // If totalMilliseconds is 0, normalizedPosition will be 0.0
    final normalizedPosition = (totalMilliseconds > 0)
        ? (currentPositionMilliseconds / totalMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    // Use dragging value if available, otherwise use normalized current position
    final sliderValue = _draggingNormalizedValue ?? normalizedPosition;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(
            value: sliderValue.clamp(0.0, 1.0), // Ensure value is always within 0.0 and 1.0
            min: 0.0,
            max: 1.0,
            onChanged: (v) {
              setState(() => _draggingNormalizedValue = v);
            },
            onChangeEnd: (v) {
              setState(() => _draggingNormalizedValue = null);
              // Convert normalized value back to duration
              final seekMilliseconds = (v * totalMilliseconds).round();
              widget.onChanged(Duration(milliseconds: seekMilliseconds));
            },
          ),
        ),
        Row(
          children: [
            Text(_fmt(widget.position),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
            const Spacer(),
            Text(_fmt(widget.duration),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ],
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onOpenUrl;
  const _EmptyState({required this.onOpenUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0B0F14), Color(0xFF0B0F14)],
      )),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.ondemand_video, size: 72),
            const SizedBox(height: 16),
            const Text(
              'Open a video to start',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: onOpenUrl,
                  icon: const Icon(Icons.link),
                  label: const Text('Open URL'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Shortcuts: Space/K Play-Pause • J/L ±5s • F Fullscreen • M Mute • +/- Speed',
              style: TextStyle(fontSize: 12, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Shortcut intents ----------
class _SeekLeftIntent extends Intent {
  const _SeekLeftIntent();
}

class _SeekRightIntent extends Intent {
  const _SeekRightIntent();
}

class _FullScreenIntent extends Intent {
  const _FullScreenIntent();
}

class _EnterFullScreenIntent extends Intent {
  const _EnterFullScreenIntent();
}

class _ExitFullScreenIntent extends Intent {
  const _ExitFullScreenIntent();
}

class _MuteIntent extends Intent {
  const _MuteIntent();
}

class _SpeedUpIntent extends Intent {
  const _SpeedUpIntent();
}

class _SpeedDownIntent extends Intent {
  const _SpeedDownIntent();
}

// ===================== Dialogs =====================

class _OpenUrlDialog extends StatefulWidget {
  const _OpenUrlDialog();

  @override
  State<_OpenUrlDialog> createState() => _OpenUrlDialogState();
}

class _OpenUrlDialogState extends State<_OpenUrlDialog> {
  final urlCtrl = TextEditingController(
    text:
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
  );
  final labelCtrl = TextEditingController(text: 'Source');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Open from URL'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: urlCtrl,
            decoration: const InputDecoration(
              labelText: 'Video URL (.mp4, etc.)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: labelCtrl,
            decoration: const InputDecoration(
              labelText: 'Quality label (e.g., 1080p)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _UrlDialogResult(urlCtrl.text.trim(), labelCtrl.text.trim()),
          ),
          child: const Text('Open'),
        ),
      ],
    );
  }
}

class _AddQualityDialog extends StatefulWidget {
  const _AddQualityDialog();

  @override
  State<_AddQualityDialog> createState() => _AddQualityDialogState();
}

class _AddQualityDialogState extends State<_AddQualityDialog> {
  final urlCtrl = TextEditingController();
  final labelCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add quality'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: labelCtrl,
            decoration: const InputDecoration(
              labelText: 'Label (e.g., 720p)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: urlCtrl,
            decoration: const InputDecoration(
              labelText: 'Video URL for this quality',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _AddQualityResult(labelCtrl.text.trim(), urlCtrl.text.trim()),
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _SubtitleUrlDialog extends StatefulWidget {
  const _SubtitleUrlDialog();

  @override
  State<_SubtitleUrlDialog> createState() => _SubtitleUrlDialogState();
}

class _SubtitleUrlDialogState extends State<_SubtitleUrlDialog> {
  final urlCtrl = TextEditingController(
    text:
        'https://raw.githubusercontent.com/Surya-211/SampleSubtitles/main/bbb-en.srt',
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Load subtitles from URL'),
      content: TextField(
        controller: urlCtrl,
        decoration: const InputDecoration(
          labelText: 'SRT/WebVTT URL',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, urlCtrl.text.trim()),
          child: const Text('Load'),
        ),
      ],
    );
  }
}

// ===================== Subtitle parsing =====================

class _SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;
  const _SubtitleCue(this.start, this.end, this.text);
}

/// Parses both SRT and WebVTT with simple, robust rules.
/// - Supports hh:mm:ss,ms and hh:mm:ss.mmm formats.
/// - Strips basic HTML tags and unescapes common entities.
List<_SubtitleCue> _parseSubtitle(String raw) {
  // Normalize newlines
  final s = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  if (s.startsWith('WEBVTT')) {
    return _parseVtt(s);
  }
  return _parseSrt(s);
}

List<_SubtitleCue> _parseSrt(String s) {
  final blocks = s.split(RegExp(r'\n\s*\n'));
  final List<_SubtitleCue> cues = [];
  final timeRe = RegExp(
      r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})\s*-->\s*(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})');

  for (var block in blocks) {
    final lines = block.trim().split('\n');
    if (lines.length < 2) continue;

    // Some SRTs start with an index line; detect time line.
    int timeLineIdx = 0;
    if (!timeRe.hasMatch(lines[0]) && lines.length >= 2) {
      timeLineIdx = 1;
    }
    if (timeLineIdx >= lines.length) continue;

    final m = timeRe.firstMatch(lines[timeLineIdx]);
    if (m == null) continue;

    final start = _toDuration(
        m.group(1), m.group(2), m.group(3), m.group(4));
    final end = _toDuration(
        m.group(5), m.group(6), m.group(7), m.group(8));

    final textLines = lines.sublist(timeLineIdx + 1);
    final text = _cleanSubtitleText(textLines.join('\n'));
    cues.add(_SubtitleCue(start, end, text));
  }
  cues.sort((a, b) => a.start.compareTo(b.start));
  return cues;
}

List<_SubtitleCue> _parseVtt(String s) {
  // Remove header line
  final body = s.split('\n').skip(1).join('\n');
  final blocks = body.split(RegExp(r'\n\s*\n'));
  final List<_SubtitleCue> cues = [];
  final timeRe = RegExp(
      r'(\d{1,2}):(\d{2}):(\d{2})(?:[.,](\d{1,3}))?\s*-->\s*(\d{1,2}):(\d{2}):(\d{2})(?:[.,](\d{1,3}))?');

  for (var block in blocks) {
    final lines = block.trim().split('\n');
    if (lines.isEmpty) continue;

    // Skip possible cue identifier line
    int idx = 0;
    if (!timeRe.hasMatch(lines[0]) && lines.length >= 2) {
      idx = 1;
    }

    if (idx >= lines.length) continue;
    final m = timeRe.firstMatch(lines[idx]);
    if (m == null) continue;

    final start = _toDuration(m.group(1), m.group(2), m.group(3), m.group(4));
    final end = _toDuration(m.group(5), m.group(6), m.group(7), m.group(8));

    final text = _cleanSubtitleText(lines.sublist(idx + 1).join('\n'));
    cues.add(_SubtitleCue(start, end, text));
  }
  cues.sort((a, b) => a.start.compareTo(b.start));
  return cues;
}

Duration _toDuration(String? h, String? m, String? s, String? ms) {
  final hh = int.tryParse(h ?? '0') ?? 0;
  final mm = int.tryParse(m ?? '0') ?? 0;
  final ss = int.tryParse(s ?? '0') ?? 0;
  var msStr = ms ?? '0';
  if (msStr.length == 1) msStr = '${msStr}00';
  if (msStr.length == 2) msStr = '${msStr}0';
  final mss = int.tryParse(msStr) ?? 0;
  return Duration(hours: hh, minutes: mm, seconds: ss, milliseconds: mss);
}

String _cleanSubtitleText(String txt) {
  // Strip simple tags and unescape minimal HTML entities.
  final noTags = txt.replaceAll(RegExp(r'<[^>]+>'), '');
  return noTags
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .trim();
}

// ===================== Small models =====================

class _UrlDialogResult {
  final String url;
  final String label;
  _UrlDialogResult(this.url, this.label);
}

class _AddQualityResult {
  final String label;
  final String url;
  _AddQualityResult(this.label, this.url);
}
