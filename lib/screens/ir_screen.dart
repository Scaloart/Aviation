import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:brie_fly/screens/pdf_viewer_screen.dart';
import 'package:brie_fly/screens/salahvideo.dart' show PlayerShell;

enum IRItemType { pdf, video }

class IRItem {
  final IRItemType type;
  final String title; // Display title
  final String fileName; // Original filename for PDFs or videos

  const IRItem({required this.type, required this.title, required this.fileName});
}

class IrScreen extends StatefulWidget {
  const IrScreen({super.key});

  @override
  State<IrScreen> createState() => _IrScreenState();
}

class _IrScreenState extends State<IrScreen> {
  // Base URL for IR folder in GitHub
  static const String _githubBaseUrl =
      'https://raw.githubusercontent.com/Scaloart/Aviation/main/IR/';

  // Static lists to be maintained
  // Add your PDF filenames (exact, including spaces/accents) from the IR repo folder
  static const List<String> _pdfFiles = [
    '2 APP PBN.pdf',
    'APP IFR.pdf',
    'Approches IFR.pdf',
    'Briefing vol IFR.pdf',
    'COURS IFR.pdf',
    'IFR_APP.pdf',
    'JEPPESEN 1.pdf',
    'JEPPESEN 2.pdf',
    'Pilots-Cafe-IFR.pdf',
  ];

  // Add your video filenames (e.g., .mp4) from the IR repo folder
  // Titles can be auto-formatted from filename or set explicitly below
  static const List<String> _videoFiles = [
    'Lecture Carte Approche Jeppesen',
  ];

  late List<IRItem> _allItems;
  List<IRItem> _filteredItems = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _allItems = [
      ..._pdfFiles.map((f) => IRItem(
            type: IRItemType.pdf,
            title: _formatTitle(f, isPdf: true),
            fileName: f,
          )),
      ..._videoFiles.map((f) => IRItem(
            type: IRItemType.video,
            title: _formatTitle(f, isPdf: false),
            fileName: f,
          )),
    ];
    _filteredItems = _allItems;
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _allItems
          .where((i) => i.title.toLowerCase().contains(q))
          .toList();
    });
  }

  static String _formatTitle(String fileName, {required bool isPdf}) {
    final withoutExt = fileName.replaceAll(isPdf ? '.pdf' : '.mp4', '');
    return withoutExt.replaceAll('_', ' ');
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
                    hintText: 'Rechercher...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(color: Colors.white),
                )
              : Text('IR',
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
                  // Desktop/Web: match DA42 VI layout (fixed 160x220 tiles, 24 spacing)
                  return Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    alignment: WrapAlignment.center,
                    children: _filteredItems
                        .map((item) => SizedBox(
                              width: 160,
                              height: 220,
                              child: _IRThumbItem(
                                item: item,
                                githubBaseUrl: _githubBaseUrl,
                                allItems: _filteredItems,
                              ),
                            ))
                        .toList(),
                  );
                }

                // Mobile: keep existing responsive behavior with min 2 columns
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
                  children: _filteredItems
                      .map((item) => SizedBox(
                            width: itemW.clamp(110, 220),
                            height: itemH.clamp(151.25, 302.5),
                            child: _IRThumbItem(
                              item: item,
                              githubBaseUrl: _githubBaseUrl,
                              allItems: _filteredItems,
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

class _IRThumbItem extends StatefulWidget {
  final IRItem item;
  final String githubBaseUrl;
  final List<IRItem> allItems; // for building a playlist of the filtered videos

  const _IRThumbItem({
    Key? key,
    required this.item,
    required this.githubBaseUrl,
    required this.allItems,
  }) : super(key: key);

  @override
  State<_IRThumbItem> createState() => _IRThumbItemState();
}

class _IRThumbItemState extends State<_IRThumbItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isPdf = widget.item.type == IRItemType.pdf;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(_isHovered ? 1.05 : 1.0),
        transformAlignment: Alignment.center,
        child: GestureDetector(
          onTap: () => isPdf ? _openPdf(context) : _openVideo(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: Image.asset(
                  isPdf ? 'assets/pdf poster.png' : 'assets/video poster.png',
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

  Future<void> _openPdf(BuildContext context) async {
    final String encodedName = Uri.encodeComponent(widget.item.fileName);
    final String pdfUrl = '${widget.githubBaseUrl}$encodedName';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          url: pdfUrl,
          title: widget.item.title,
        ),
      ),
    );
  }

  void _openVideo(BuildContext context) {
    // Build a playlist from the currently filtered items (videos only)
    final videos = widget.allItems.where((i) => i.type == IRItemType.video).toList();
    final urls = videos.map((v) {
      if (v.fileName == 'Lecture Carte Approche Jeppesen') {
        // Use the provided MP4 link exclusively
        return 'https://ia801000.us.archive.org/26/items/lecture-carte-approche-jeppesen_202508/Lecture%20Carte%20Approche%20Jeppesen.mp4';
      }
      return '${widget.githubBaseUrl}${Uri.encodeComponent(v.fileName)}';
    }).toList();
    final titles = videos.map((v) => v.title).toList();
    final currentIndex = videos.indexWhere((v) => v.fileName == widget.item.fileName);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerShell(
          videoUrl: urls.isNotEmpty ? urls[currentIndex] : null,
          videoTitle: titles.isNotEmpty ? titles[currentIndex] : null,
          playlistUrls: urls.isNotEmpty ? urls : null,
          playlistTitles: titles.isNotEmpty ? titles : null,
          initialIndex: currentIndex >= 0 ? currentIndex : 0,
        ),
      ),
    );
  }
}

