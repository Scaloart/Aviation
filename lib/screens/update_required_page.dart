import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
// window_manager not needed here; app-level window bar is already provided
import 'package:brie_fly/widgets/background_container.dart';
import 'package:google_fonts/google_fonts.dart';

class UpdateRequiredPage extends StatefulWidget {
  final String latestVersion;
  final String notes;
  final String installerUrl;

  const UpdateRequiredPage({
    super.key,
    required this.latestVersion,
    required this.notes,
    required this.installerUrl,
  });

  @override
  State<UpdateRequiredPage> createState() => _UpdateRequiredPageState();
}

class _UpdateRequiredPageState extends State<UpdateRequiredPage> {
  bool _downloading = false;
  double _progress = 0;
  String? _status;

  bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  // Download metrics
  int _totalBytes = 0;
  int _receivedBytes = 0;
  DateTime? _downloadStart;
  Timer? _uiTicker;
  String? _currentFilePath;
  http.Client? _client;
  StreamSubscription<List<int>>? _subscription;
  bool _isPaused = false;

  String _formatBytes(int bytes) {
    const units = ['o', 'Ko', 'Mo', 'Go'];
    double v = bytes.toDouble();
    int i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v < 10 ? 2 : 1)} ${units[i]}';
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  // No custom window bar; we rely on the app's existing window/title bar.

  // Browser fallback removed per request; direct download only.

  String _simpleVersion(String v) {
    final i = v.indexOf('+');
    return i >= 0 ? v.substring(0, i) : v;
  }

  List<String> _extractChangelogItems(String notes) {
    final lines = notes.split('\n');
    final items = <String>[];
    final bulletPrefixes = ['- ', '* ', '• '];
    final numberReg = RegExp(r'^(\d+)[\.)]\s+');
    for (var raw in lines) {
      var line = raw.trim();
      if (line.isEmpty) continue;
      bool matched = false;
      for (final p in bulletPrefixes) {
        if (line.startsWith(p)) {
          items.add(line.substring(p.length).trim());
          matched = true;
          break;
        }
      }
      if (matched) continue;
      final m = numberReg.firstMatch(line);
      if (m != null) {
        items.add(line.substring(m.group(0)!.length).trim());
        continue;
      }
      // Fallback: treat as an item if we already have items
      if (items.isNotEmpty) {
        items.add(line);
      } else {
        // keep as a single summary item
        items.add(line);
      }
    }
    // De-duplicate empties
    return items.where((e) => e.isNotEmpty).toList();
  }

  Widget _buildPrimaryDownloadButton({required bool isPhone}) {
    final bg = const Color(0xFFFF1744); // matches Welcome progress color
    final onBg = Colors.white;
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: isPhone ? double.infinity : 320, maxWidth: 420),
      child: ElevatedButton(
        onPressed: _downloading ? null : _downloadAndRunInstaller,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: onBg,
          disabledBackgroundColor: bg.withOpacity(0.5),
          disabledForegroundColor: onBg.withOpacity(0.8),
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: isPhone ? 16 : 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.download, size: 22),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Télécharger et installer',
                  style: GoogleFonts.roboto(fontSize: isPhone ? 15 : 16, fontWeight: FontWeight.w700, color: onBg),
                ),
                const SizedBox(height: 2),
                Text(
                  'Version ${_simpleVersion(widget.latestVersion)} • Configuration automatique',
                  style: GoogleFonts.roboto(fontSize: isPhone ? 11.5 : 12.5, color: onBg.withOpacity(0.95)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadAndRunInstaller() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _status = 'Téléchargement…';
      _progress = 0;
      _totalBytes = 0;
      _receivedBytes = 0;
      _downloadStart = DateTime.now();
      _isPaused = false;
    });
    try {
      final tempDir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      _currentFilePath = '${tempDir.path}/BrieFly_Setup_$ts.exe';
      await _startOrResumeDownload(startAt: 0);
    } catch (e) {
      debugPrint('[UpdateRequiredPage] Download failed (init): $e');
      setState(() {
        _status = "Échec du téléchargement.";
        _downloading = false;
      });
    }
  }

  Future<void> _startOrResumeDownload({required int startAt}) async {
    // set up UI ticker
    _uiTicker?.cancel();
    _uiTicker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final elapsed = _downloadStart != null ? DateTime.now().difference(_downloadStart!) : const Duration();
      final speedBps = elapsed.inMilliseconds > 0 ? (_receivedBytes * 1000) / (elapsed.inMilliseconds) : 0.0;
      final remainingBytes = (_totalBytes > 0) ? (_totalBytes - _receivedBytes) : 0;
      final remainingMs = (speedBps > 0 && remainingBytes > 0) ? (remainingBytes / speedBps) * 1000 : 0;
      final eta = remainingMs > 0 ? _formatDuration(Duration(milliseconds: remainingMs.round())) : '';
      setState(() {
        _status = _totalBytes > 0
            ? '${(_progress * 100).toStringAsFixed(1)}% • ${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)} • ${_formatBytes(speedBps.round())}/s${eta.isNotEmpty ? ' • ETA $eta' : ''}'
            : _receivedBytes > 0
                ? '${_formatBytes(_receivedBytes)} téléchargés…'
                : 'Connexion…';
      });
    });

    _client?.close();
    _client = http.Client();
    final req = http.Request('GET', Uri.parse(widget.installerUrl));
    if (startAt > 0) {
      req.headers['Range'] = 'bytes=$startAt-';
    }
    final res = await _client!.send(req);

    // If server ignored Range and we attempted resume, restart from 0
    if (startAt > 0 && res.statusCode == 200) {
      try { await _subscription?.cancel(); } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 10));
      // Reset file to avoid duplicate content
      try {
        final f = File(_currentFilePath!);
        if (await f.exists()) {
          await f.delete();
        }
        _receivedBytes = 0;
        _progress = 0;
        _totalBytes = res.contentLength ?? 0;
      } catch (_) {}
      // Recurse with fresh request from 0
      await _startOrResumeDownload(startAt: 0);
      return;
    }

    // If total unknown, try to infer from Content-Length or Content-Range
    if (_totalBytes == 0) {
      final remaining = res.contentLength ?? 0;
      if (remaining > 0) {
        _totalBytes = startAt + remaining;
      }
      final cr = res.headers['content-range'];
      if (cr != null) {
        // format: bytes start-end/total
        final slash = cr.lastIndexOf('/');
        if (slash != -1) {
          final totalStr = cr.substring(slash + 1).trim();
          final total = int.tryParse(totalStr);
          if (total != null && total > 0) {
            _totalBytes = total;
          }
        }
      }
    }

    final file = File(_currentFilePath!);
    final sink = file.openWrite(mode: startAt > 0 ? FileMode.append : FileMode.write);

    _subscription = res.stream.listen((chunk) {
      if (_isPaused) return; // ignore if marked paused (subscription may be in canceling)
      _receivedBytes += chunk.length;
      sink.add(chunk);
      if (_totalBytes > 0) {
        final p = _receivedBytes / _totalBytes;
        if (p - _progress >= 0.001) {
          if (mounted) setState(() { _progress = p; });
        }
      } else {
        if (mounted) setState(() { _progress = 0; });
      }
    }, onDone: () async {
      await sink.close();
      _uiTicker?.cancel();
      if (_isPaused) {
        // paused, do not proceed
        return;
      }
      if (!mounted) return;
      setState(() { _status = 'Lancement de l\'installateur…'; });
      try {
        await Process.start(_currentFilePath!, [], mode: ProcessStartMode.detached);
      } catch (e) {
        debugPrint('[UpdateRequiredPage] Failed to start installer: $e');
        // Fallback to opening URL
        await launchUrl(Uri.parse(widget.installerUrl), mode: LaunchMode.externalApplication);
      }
      try { exit(0); } catch (_) {}
    }, onError: (e, st) async {
      await sink.close();
      _uiTicker?.cancel();
      if (!mounted) return;
      setState(() {
        _status = "Échec du téléchargement.";
        _downloading = false;
      });
    }, cancelOnError: true);
  }

  Future<void> _pauseDownload() async {
    if (!_downloading || _isPaused) return;
    _isPaused = true;
    _status = 'En pause';
    try { await _subscription?.cancel(); } catch (_) {}
    try { _client?.close(); } catch (_) {}
    _uiTicker?.cancel();
    if (mounted) setState(() {});
  }

  Future<void> _resumeDownload() async {
    if (!_downloading || !_isPaused) return;
    _isPaused = false;
    _downloadStart = DateTime.now(); // restart timer for speed calc from resume
    if (mounted) setState(() { _status = 'Reprise…'; });
    await _startOrResumeDownload(startAt: _receivedBytes);
  }

  Future<void> _cancelDownload() async {
    if (!_downloading) return;
    _isPaused = false;
    try { await _subscription?.cancel(); } catch (_) {}
    try { _client?.close(); } catch (_) {}
    _uiTicker?.cancel();
    try {
      if (_currentFilePath != null) {
        final f = File(_currentFilePath!);
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _downloading = false;
      _status = 'Téléchargement annulé';
      _progress = 0;
      _totalBytes = 0;
      _receivedBytes = 0;
    });
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    try { _subscription?.cancel(); } catch (_) {}
    try { _client?.close(); } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !kReleaseMode, // allow pop in debug/profile
      child: Scaffold(
        body: BackgroundContainer(
          showBottomBanner: false,
          padForBanner: false,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = MediaQuery.of(context).size;
              final bool isDesktop = _isDesktop;
              final bool isPhone = !isDesktop && size.width < 600;
              final double logoHeight = isPhone ? (size.height * 0.18).clamp(96.0, 160.0) : 160.0;
              final double titleFontSize = isPhone ? (size.width < 360 ? 26 : 32) : 36;
              final double progressFont = isPhone ? 13 : 14;
              final double statusFont = isPhone ? 12 : 13;

              return Stack(
                children: [
                  // Centered content
                  Center(
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
                              Icons.system_update,
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
                          SizedBox(height: isPhone ? 6 : 8),

                          // Subtitle
                          Text(
                            'Mise à jour requise — version minimale ${_simpleVersion(widget.latestVersion)}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.roboto(
                              fontSize: progressFont,
                              color: Colors.grey[300],
                            ),
                          ),
                          if (widget.notes.isNotEmpty) ...[
                            SizedBox(height: isPhone ? 10 : 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final items = _extractChangelogItems(widget.notes);
                                    if (items.length <= 1) {
                                      return SelectableText(widget.notes);
                                    }
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        for (final item in items)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Padding(
                                                  padding: EdgeInsets.only(top: 3),
                                                  child: Icon(Icons.check_circle_outline, size: 16, color: Color(0xFFFF1744)),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(child: Text(item)),
                                              ],
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],

                          SizedBox(height: isPhone ? 18 : 22),
                          if (!_downloading)
                            Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildPrimaryDownloadButton(isPhone: isPhone),
                                if (_status == 'Échec du téléchargement.')
                                  OutlinedButton.icon(
                                    onPressed: _downloadAndRunInstaller,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Réessayer'),
                                  ),
                              ],
                            ),

                          // Reserve space so bottom bar doesn't overlap
                          SizedBox(height: isPhone ? 96 : 120),
                        ],
                      ),
                    ),
                  ),

                  // Bottom progress section (visible during download)
                  if (_downloading)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(isPhone ? 20 : 64, 0, isPhone ? 20 : 64, isPhone ? 12 : 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Téléchargement de la mise à jour…',
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
                                  value: _totalBytes == 0 ? null : _progress,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _status ?? '',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.robotoMono(
                                  fontSize: statusFont,
                                  color: Colors.grey[300],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  if (!_isPaused)
                                    OutlinedButton.icon(
                                      onPressed: _pauseDownload,
                                      icon: const Icon(Icons.pause),
                                      label: const Text('Mettre en pause'),
                                    ),
                                  if (_isPaused)
                                    ElevatedButton.icon(
                                      onPressed: _resumeDownload,
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('Reprendre'),
                                    ),
                                  TextButton.icon(
                                    onPressed: _cancelDownload,
                                    icon: const Icon(Icons.stop),
                                    label: const Text('Annuler'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
