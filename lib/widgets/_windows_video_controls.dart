import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class WindowsVideoControls extends StatefulWidget {
  final VideoPlayerController controller;
  final List<String>? qualities;
  final ValueChanged<String>? onQualitySelected;
  final List<double>? speeds;
  final List<String>? subtitles;
  final ValueChanged<String>? onSubtitleSelected;
  final String? currentSubtitle;
  const WindowsVideoControls({
    Key? key,
    required this.controller,
    this.qualities,
    this.onQualitySelected,
    this.speeds,
    this.subtitles,
    this.onSubtitleSelected,
    this.currentSubtitle,
  }) : super(key: key);

  @override
  State<WindowsVideoControls> createState() => WindowsVideoControlsState();
}

class WindowsVideoControlsState extends State<WindowsVideoControls> {
  bool _fullscreen = false;
  bool _visible = true;
  Timer? _hideTimer;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_controllerListener);
    _muted = widget.controller.value.volume == 0.0;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_controllerListener);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _controllerListener() {
    if (mounted) setState(() {});
  }

  void _showControls() {
    setState(() => _visible = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _togglePlay() {
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
    _showControls();
  }

  void _onSeek(double value) {
    final duration = widget.controller.value.duration;
    final pos = Duration(milliseconds: (duration.inMilliseconds * value).toInt());
    widget.controller.seekTo(pos);
    _showControls();
  }

  void _toggleMute() {
    if (_muted) {
      widget.controller.setVolume(1.0);
    } else {
      widget.controller.setVolume(0.0);
    }
    setState(() => _muted = !_muted);
    _showControls();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0 ? '${h}:${twoDigits(m)}:${twoDigits(s)}' : '${twoDigits(m)}:${twoDigits(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.controller.value.duration;
    final position = widget.controller.value.position;
    final isPlaying = widget.controller.value.isPlaying;
    final buffered = widget.controller.value.buffered;
    double bufferedEnd = buffered.isNotEmpty ? buffered.last.end.inMilliseconds / (duration.inMilliseconds == 0 ? 1 : duration.inMilliseconds) : 0.0;
    final showCentralButton = !isPlaying;

    return Stack(
      fit: StackFit.expand,
      children: [
        // TEST BUTTON: Replace all controls with a single button
        Center(
          child: ElevatedButton(
            onPressed: () {
              print('TEST BUTTON PRESSED');
            },
            child: const Text('TEST BUTTON'),
          ),
        ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54],
              ),
            ),
            foregroundDecoration: BoxDecoration(
              border: Border.all(color: Colors.redAccent, width: 1), // debug border
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Seek bar
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    ),
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        LinearProgressIndicator(
                          value: bufferedEnd,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white24),
                          backgroundColor: Colors.transparent,
                          minHeight: 3,
                        ),
                        Slider(
                          value: duration.inMilliseconds == 0 ? 0 : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0),
                          onChanged: (v) => _onSeek(v),
                          activeColor: Colors.white,
                          inactiveColor: Colors.white38,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 30),
                        onPressed: _togglePlay,
                        tooltip: isPlaying ? 'Pause' : 'Play',
                      ),
                      IconButton(
                        icon: Icon(_muted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 24),
                        onPressed: _toggleMute,
                        tooltip: _muted ? 'Unmute' : 'Mute',
                      ),
                      Text(
                        '${_formatDuration(position)} / ${_formatDuration(duration)}',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const Spacer(),
                      // Speed dropdown
                      if (widget.speeds != null && widget.speeds!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: DropdownButton<double>(
                            value: widget.controller.value.playbackSpeed,
                            dropdownColor: Colors.black87,
                            icon: const Icon(Icons.speed, color: Colors.white, size: 20),
                            underline: const SizedBox.shrink(),
                            style: const TextStyle(color: Colors.white),
                            items: widget.speeds!
                                .map((speed) => DropdownMenuItem<double>(
                                      value: speed,
                                      child: Text('${speed}x'),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                widget.controller.setPlaybackSpeed(v);
                                setState(() {});
                              }
                            },
                          ),
                        ),
                      // Quality dropdown
                      if (widget.qualities != null && widget.qualities!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: DropdownButton<String>(
                            value: widget.qualities!.first,
                            dropdownColor: Colors.black87,
                            icon: const Icon(Icons.high_quality, color: Colors.white, size: 20),
                            underline: const SizedBox.shrink(),
                            style: const TextStyle(color: Colors.white),
                            items: widget.qualities!
                                .map((q) => DropdownMenuItem<String>(
                                      value: q,
                                      child: Text(q),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null && widget.onQualitySelected != null) {
                                widget.onQualitySelected!(v);
                              }
                            },
                          ),
                        ),
                      // Subtitles dropdown
                      if (widget.subtitles != null && widget.subtitles!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: DropdownButton<String>(
                            value: widget.currentSubtitle ?? widget.subtitles!.first,
                            dropdownColor: Colors.black87,
                            icon: const Icon(Icons.subtitles, color: Colors.white, size: 20),
                            underline: const SizedBox.shrink(),
                            style: const TextStyle(color: Colors.white),
                            items: widget.subtitles!
                                .map((s) => DropdownMenuItem<String>(
                                      value: s,
                                      child: Text(s),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null && widget.onSubtitleSelected != null) {
                                widget.onSubtitleSelected!(v);
                              }
                            },
                          ),
                        ),
                      // Fullscreen toggle
                      IconButton(
                        icon: Icon(_fullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white, size: 28),
                        onPressed: _toggleFullscreen,
                        tooltip: _fullscreen ? 'Exit fullscreen' : 'Fullscreen',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // Central play/pause button (never blocks controls bar)
        if (showCentralButton)
          Center(
            child: GestureDetector(
              onTap: _togglePlay,
              child: Visibility(
                visible: showCentralButton,
                maintainState: true,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
        // Overlay for mouse/tap to show controls (does not block controls bar)
        MouseRegion(
          onHover: (_) => _showControls(),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _showControls,
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }

  void _toggleFullscreen() {
    setState(() {
      _fullscreen = !_fullscreen;
      if (_fullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });
  }
}
