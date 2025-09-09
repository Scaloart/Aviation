import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:brie_fly/screens/salahvideo.dart' show PlayerShell;

class EnglishL4TaskScreen extends StatefulWidget {
  final String folderName;
  final List<String> files; // e.g., ["1.mp4", "2.mp4", ...]
  const EnglishL4TaskScreen({super.key, required this.folderName, required this.files});

  @override
  State<EnglishL4TaskScreen> createState() => _EnglishL4TaskScreenState();
}

class _EnglishL4TaskScreenState extends State<EnglishL4TaskScreen> {
  static const String _githubBaseUrl =
      'https://raw.githubusercontent.com/Scaloart/Aviation/main/ENGLISH%20L4/last/';

  // Per-folder bases (Archive.org) per user request
  static const Map<String, String> _folderBases = {
    'TASK 1 PICTURES': 'https://archive.org/download/13_20250828/',
    'TASK 2 DIALOGUES & QUESTIONS': 'https://archive.org/download/7_20250829_20250829_1808/',
    'TASK 3 PRONOUNCIATION': 'https://archive.org/download/9_20250829_20250829_2255/',
    'TASK 4 READBACKS': 'https://archive.org/download/3_20250830_20250830_1235/',
    // TASK 5 SHORT STORIES: remains on GitHub (non-video sources in repo)
    'TASK 6 TRAFFIC ANIMATION': 'https://archive.org/download/9_20250830_20250830/',
    'TASK 7 SHORT QUESTIONS': 'https://archive.org/download/25_20250830/',
  };

  // For folders that should come from GitHub but not under ENGLISH L4/last,
  // provide explicit raw paths (URL-encoded as needed)
  static const Map<String, String> _githubFolderOverrides = {
    'TASK 5 SHORT STORIES': 'English/TASK%205%20%20Short%20stories',
    'TASK_Announcements': 'English/Task%20annoucements',
  };

  late final List<_VideoItem> _videos;
  List<_VideoItem> _filtered = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    final sorted = [...widget.files]..sort((a, b) {
      // natural-ish sort: compare by numeric value if both start numeric, else fallback
      int? ai = int.tryParse(a.split('.').first);
      int? bi = int.tryParse(b.split('.').first);
      if (ai != null && bi != null) return ai.compareTo(bi);
      return a.compareTo(b);
    });

    _videos = sorted
        .where((f) => f.toLowerCase().endsWith('.mp4'))
        .where((f) => _isAvailable(widget.folderName, f))
        .map((f) => _VideoItem(
              title: _prettyTitle(f),
              url: _buildUrlForFolder(widget.folderName, f),
            ))
        .toList();
    _filtered = _videos;
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _videos.where((v) => v.title.toLowerCase().contains(q)).toList();
    });
  }

  String _buildUrlForFolder(String folder, String file) {
    // Special case: TASK 1 items 1-9 come from GitHub (per user request)
    if (folder == 'TASK 1 PICTURES') {
      final baseName = file.split('.').first;
      final n = int.tryParse(baseName);
      if (n != null && n >= 1 && n <= 9) {
        final encFile = Uri.encodeComponent(file);
        final encFolder = Uri.encodeComponent(folder);
        return '$_githubBaseUrl$encFolder/$encFile';
      }
    }
    final base = _folderBases[folder];
    if (base != null) {
      // For Archive.org items, prefer the transcoded variant (.ia.mp4) for better playback
      // when the incoming file name ends with .mp4.
      final preferIaFor = {
        'TASK 1 PICTURES',
        'TASK 2 DIALOGUES & QUESTIONS',
        'TASK 3 PRONOUNCIATION',
        'TASK 4 READBACKS',
      };
      String fileName = file;
      if (preferIaFor.contains(folder) && fileName.toLowerCase().endsWith('.mp4')) {
        fileName = fileName.substring(0, fileName.length - 4) + '.ia.mp4';
      }
      final encFile = Uri.encodeComponent(fileName);
      return '$base$encFile';
    }
    // Fallback to GitHub raw. Use override path if provided, else default ENGLISH L4/last
    final encFile = Uri.encodeComponent(file);
    final override = _githubFolderOverrides[folder];
    if (override != null) {
      return 'https://raw.githubusercontent.com/Scaloart/Aviation/main/$override/$encFile';
    }
    final encFolder = Uri.encodeComponent(folder);
    return '$_githubBaseUrl$encFolder/$encFile';
  }

  bool _isAvailable(String folder, String file) {
    // All items are available; TASK 1 items 1-9 are sourced from GitHub
    return true;
  }

  String _prettyTitle(String fileName) {
    final base = fileName.replaceAll('.mp4', '');
    return 'Video $base';
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(color: Colors.white),
                )
              : Text(widget.folderName,
                  style: GoogleFonts.montserrat(
                      color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) _searchController.clear();
                });
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(context).size.width < 600
                ? (MediaQuery.of(context).padding.bottom + 32)
                : 24,
          ),
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
                if (!isMobile) {
                  return Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    alignment: WrapAlignment.center,
                    children: _filtered
                        .map((v) => SizedBox(
                              width: 160,
                              height: 220,
                              child: _ThumbItem(
                                item: v,
                                playlist: _filtered,
                                initialIndex: _filtered.indexOf(v),
                              ),
                            ))
                        .toList(),
                  );
                }

                final maxW = constraints.maxWidth;
                int cols;
                if (maxW >= 1200) {
                  cols = (maxW / 184).floor();
                  if (cols < 4) cols = 4;
                } else if (maxW >= 900) {
                  cols = 4;
                } else if (maxW >= 600) {
                  cols = 3;
                } else if (maxW >= 380) {
                  cols = 2;
                } else {
                  cols = 2;
                }

                const double aspect = 220 / 160;
                final double spacing = maxW < 400 ? 12 : 16;
                final double itemW = (maxW - (cols - 1) * spacing) / cols;
                final double itemH = itemW * aspect;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  alignment: WrapAlignment.center,
                  children: _filtered
                      .map((v) => SizedBox(
                            width: itemW.clamp(110, 220),
                            height: itemH.clamp(151.25, 302.5),
                            child: _ThumbItem(
                              item: v,
                              playlist: _filtered,
                              initialIndex: _filtered.indexOf(v),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoItem {
  final String title;
  final String url;
  const _VideoItem({required this.title, required this.url});
}

class _ThumbItem extends StatefulWidget {
  final _VideoItem item;
  final List<_VideoItem> playlist;
  final int initialIndex;
  const _ThumbItem({required this.item, required this.playlist, required this.initialIndex});

  @override
  State<_ThumbItem> createState() => _ThumbItemState();
}

class _ThumbItemState extends State<_ThumbItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(_isHovered ? 1.05 : 1.0),
        transformAlignment: Alignment.center,
        child: GestureDetector(
          onTap: _openVideo,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: Image.asset(
                  'assets/video poster.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  widget.item.title,
                  style: GoogleFonts.lato(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openVideo() {
    final urls = widget.playlist.map((v) => v.url).toList();
    final titles = widget.playlist.map((v) => v.title).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerShell(
          videoUrl: urls[widget.initialIndex],
          videoTitle: titles[widget.initialIndex],
          playlistUrls: urls,
          playlistTitles: titles,
          initialIndex: widget.initialIndex,
        ),
      ),
    );
  }
}

