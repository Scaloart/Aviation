import 'dart:io';
import 'package:flutter/material.dart';
import 'package:better_player_enhanced/better_player.dart';
import 'package:video_player/video_player.dart' as vp;
import 'package:window_manager/window_manager.dart';
import 'windows_video_controls_bar.dart';

class CustomVideoPlayer extends StatefulWidget {
  final String url;
  final Map<String, String>? resolutions;
  final List<BetterPlayerSubtitlesSource>? subtitles;
  final String? poster;
  final bool autoPlay;
  final void Function()? onPlay;
  final void Function()? onPause;
  final void Function(Duration position)? onProgress;
  final void Function()? onCompleted;

  const CustomVideoPlayer({
    Key? key,
    required this.url,
    this.resolutions,
    this.subtitles,
    this.poster,
    this.autoPlay = true,
    this.onPlay,
    this.onPause,
    this.onProgress,
    this.onCompleted,
  }) : super(key: key);

  @override
  State<CustomVideoPlayer> createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends State<CustomVideoPlayer> {
  late BetterPlayerController _controller;
  bool _initialized = false;

  // Windows (video_player)
  vp.VideoPlayerController? _vpController;
  bool _vpInitialized = false;
  bool _isFullScreenWindows = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    if (Platform.isWindows) {
      // Native playback via video_player (Media Foundation)
      final c = vp.VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _vpController = c;
      c.initialize().then((_) async {
        if (!mounted) return;
        setState(() => _vpInitialized = true);
        if (widget.autoPlay) await c.play();
      }).catchError((e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playback error: $e')),
        );
      });
      return;
    }

    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      widget.url,
      resolutions: widget.resolutions,
      placeholder: widget.poster != null
          ? Image.network(widget.poster!, fit: BoxFit.cover)
          : null,
      subtitles: widget.subtitles,
    );

    _controller = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: widget.autoPlay,
        fit: BoxFit.contain,
        expandToFill: true,
        allowedScreenSleep: false,
        // No fixed aspect ratio; let the parent constraints drive size
        showPlaceholderUntilPlay: widget.poster != null,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: true,
          enablePlayPause: true,
          enableSkips: true,
          enableFullscreen: true,
          enableSubtitles: true,
          enableQualities: true,
          loadingColor: Colors.white,
          controlBarColor: Colors.black54,
          iconsColor: Colors.white,
          overflowMenuIconsColor: Colors.white,
        ),
      ),
      betterPlayerDataSource: dataSource,
    );

    _controller.addEventsListener((event) async {
      // Verbose logging to diagnose playback issues on desktop
      // ignore: avoid_print
      print("[CustomVideoPlayer] Event: ${event.betterPlayerEventType} params=${event.parameters}");
      switch (event.betterPlayerEventType) {
        case BetterPlayerEventType.initialized:
          setState(() => _initialized = true);
          break;
        case BetterPlayerEventType.play:
          widget.onPlay?.call();
          break;
        case BetterPlayerEventType.pause:
          widget.onPause?.call();
          break;
        case BetterPlayerEventType.progress:
          final position = await _controller.videoPlayerController?.position;
          if (position != null) widget.onProgress?.call(position);
          break;
        case BetterPlayerEventType.finished:
          widget.onCompleted?.call();
          break;
        default:
          break;
      }
    });
  }

  Future<void> _toggleFullScreenWindows() async {
    if (!Platform.isWindows) return;
    // In-app fullscreen: push a route that fills the client area, keep window title bar intact
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _WindowsInAppFullscreen(
          controller: _vpController!,
          buildControls: () => WindowsVideoControlsBar(
            controller: _vpController!,
            qualities: widget.resolutions?.keys.toList(),
            onQualitySelected: (q) {
              if (widget.resolutions != null && widget.resolutions![q] != null) {
                final url = widget.resolutions![q]!;
                final pos = _vpController!.value.position;
                _vpController!.pause();
                _vpController!.dispose();
                setState(() {
                  _vpController = vp.VideoPlayerController.network(url)
                    ..initialize().then((_) {
                      _vpController!.seekTo(pos);
                      if (widget.autoPlay) _vpController!.play();
                      setState(() {});
                    });
                });
              }
            },
            speeds: const [0.25, 0.5, 1.0, 1.5, 2.0],
            subtitles: widget.subtitles?.map((s) => s.name).whereType<String>().toList(),
            onSubtitleSelected: (s) {/* handle subtitle selection */},
            currentSubtitle: null,
            onToggleFullScreen: () => Navigator.of(context).maybePop(),
          ),
        ),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  Future<void> _seekRelative(Duration delta) async {
    if (Platform.isWindows) {
      final c = _vpController;
      if (c == null) return;
      final pos = await c.position ?? Duration.zero;
      final dur = c.value.duration;
      var target = pos + delta;
      if (target < Duration.zero) target = Duration.zero;
      if (dur > Duration.zero && target > dur) target = dur;
      await c.seekTo(target);
      return;
    }
    final video = _controller.videoPlayerController;
    if (video == null) return;
    final current = await video.position ?? Duration.zero;
    final total = video.value.duration ?? Duration.zero;
    var target = current + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (total > Duration.zero && target > total) target = total;
    await _controller.seekTo(target);
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      _vpController?.dispose();
    } else {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (Platform.isWindows) {
          if (!_vpInitialized) return KeyEventResult.ignored;
        } else {
          if (!_initialized) return KeyEventResult.ignored;
        }
        if (event.logicalKey.keyLabel == ' ') {
          if (!Platform.isWindows) {
            final playing = _controller.isPlaying() ?? false;
            if (playing) {
              _controller.pause();
            } else {
              _controller.play();
            }
          } else {
            final c = _vpController!;
            if (c.value.isPlaying) {
              c.pause();
            } else {
              c.play();
            }
          }
          return KeyEventResult.handled;
        }
        if (event.logicalKey.keyLabel == 'ArrowRight') {
          _seekRelative(const Duration(seconds: 10));
          return KeyEventResult.handled;
        }
        if (event.logicalKey.keyLabel == 'ArrowLeft') {
          _seekRelative(const Duration(seconds: -10));
          return KeyEventResult.handled;
        }
        if (event.logicalKey.keyLabel.toLowerCase() == 'f') {
          if (!Platform.isWindows) {
            _controller.enterFullScreen();
          } else {
            _toggleFullScreenWindows();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: _buildPlayerWithOverlay(),
    );
  }

  Widget _buildPlayerWithOverlay() {
    final Widget playerArea = Platform.isWindows
        ? _buildWindowsPlayer()
        : BetterPlayer(controller: _controller);

    final Widget stacked = Stack(
      fit: StackFit.expand,
      children: [
        playerArea,
        if (!(Platform.isWindows ? _vpInitialized : _initialized))
          const Center(child: CircularProgressIndicator()),
      ],
    );

    // Fill available space; fullscreen uses a separate route on Windows
    return stacked;
  }

  Widget _buildWindowsPlayer() {
    if (_vpController == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: _vpController!.value.aspectRatio > 0
                ? _vpController!.value.aspectRatio
                : 16 / 9,
            child: vp.VideoPlayer(_vpController!),
          ),
        ),
        WindowsVideoControlsBar(
          controller: _vpController!,
          qualities: widget.resolutions?.keys.toList(),
          onQualitySelected: (q) {
            if (widget.resolutions != null && widget.resolutions![q] != null) {
              final url = widget.resolutions![q]!;
              final pos = _vpController!.value.position;
              _vpController!.pause();
              _vpController!.dispose();
              setState(() {
                _vpController = vp.VideoPlayerController.network(url)
                  ..initialize().then((_) {
                    _vpController!.seekTo(pos);
                    if (widget.autoPlay) _vpController!.play();
                    setState(() {});
                  });
              });
            }
          },
          speeds: const [0.25, 0.5, 1.0, 1.5, 2.0],
          subtitles:
              widget.subtitles?.map((s) => s.name).whereType<String>().toList(),
          onSubtitleSelected: (s) {/* handle subtitle selection */},
          currentSubtitle: null,
          onToggleFullScreen: _toggleFullScreenWindows,
        ),
      ],
    );
  }

}

class _WindowsInAppFullscreen extends StatelessWidget {
  final vp.VideoPlayerController controller;
  final Widget Function() buildControls;
  const _WindowsInAppFullscreen({required this.controller, required this.buildControls});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        child: GestureDetector(
          onTap: () {},
          onDoubleTap: () => Navigator.of(context).maybePop(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: ValueListenableBuilder<vp.VideoPlayerValue>(
                  valueListenable: controller,
                  builder: (context, v, _) {
                    final ar = v.aspectRatio > 0 ? v.aspectRatio : 16 / 9;
                    return AspectRatio(
                      aspectRatio: ar,
                      child: vp.VideoPlayer(controller),
                    );
                  },
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Material(
                  color: Colors.transparent,
                  child: buildControls(),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Material(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                  child: IconButton(
                    tooltip: 'Exit Fullscreen',
                    icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
