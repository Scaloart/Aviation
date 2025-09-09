import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class WindowsVideoControlsBar extends StatefulWidget {
  final VoidCallback? onToggleFullScreen;
  final VideoPlayerController controller;
  final List<String>? qualities;
  final ValueChanged<String>? onQualitySelected;
  final List<double>? speeds;
  final List<String>? subtitles;
  final ValueChanged<String>? onSubtitleSelected;
  final String? currentSubtitle;
  const WindowsVideoControlsBar({
    this.onToggleFullScreen,
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
  State<WindowsVideoControlsBar> createState() => _WindowsVideoControlsBarState();
}

class _WindowsVideoControlsBarState extends State<WindowsVideoControlsBar> {
  bool _muted = false;
  double _sliderValue = 0.0;
  String? _selectedQuality;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_controllerListener);
    _muted = widget.controller.value.volume == 0.0;
    if (widget.qualities != null && widget.qualities!.isNotEmpty) {
      _selectedQuality = widget.qualities!.first;
    }
  }
  @override
  void dispose() {
    widget.controller.removeListener(_controllerListener);
    super.dispose();
  }
  void _controllerListener() {
    if (mounted) setState(() {});
  }
  void _togglePlay() {
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
  }
  void _onSeek(double value) {
    final duration = widget.controller.value.duration;
    final pos = Duration(milliseconds: (duration.inMilliseconds * value).toInt());
    widget.controller.seekTo(pos);
  }
  void _toggleMute() {
    if (_muted) {
      widget.controller.setVolume(1.0);
    } else {
      widget.controller.setVolume(0.0);
    }
    setState(() => _muted = !_muted);
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
    return Material(
      color: Colors.black.withOpacity(0.75),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                SizedBox(
                  width: 80,
                  child: Slider(
                    value: widget.controller.value.volume.clamp(0.0, 1.0),
                    min: 0,
                    max: 1.0,
                    onChanged: (v) {
                      setState(() {
                        _muted = v == 0.0;
                      });
                      widget.controller.setVolume(v);
                    },
                  ),
                ),
                Text(
                  '${_formatDuration(position)} / ${_formatDuration(duration)}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const Spacer(),
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
                if (widget.qualities != null && widget.qualities!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButton<String>(
                      value: widget.qualities!.contains(_selectedQuality) ? _selectedQuality : widget.qualities!.first,
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
                          setState(() {
                            _selectedQuality = v;
                          });
                          widget.onQualitySelected!(v);
                        }
                      },
                    ),
                  ),
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
                IconButton(
                  icon: Icon(Icons.fullscreen, color: Colors.white, size: 28),
                  onPressed: () {
                    // Call a provided callback or toggle a state variable for fullscreen
                    if (widget.onToggleFullScreen != null) {
                      widget.onToggleFullScreen!();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
