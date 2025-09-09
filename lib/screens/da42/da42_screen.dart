import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:brie_fly/screens/pdf_viewer_screen.dart';

class Document {
  final String title;
  final String url; // to be set after GitHub upload
  Document({required this.title, required this.url});
}

class DA42Screen extends StatefulWidget {
  const DA42Screen({super.key});

  @override
  State<DA42Screen> createState() => _DA42ScreenState();
}

class _DA42ScreenState extends State<DA42Screen> {
  // Central GitHub raw base for DA42 VI DOCUMENTS
  static const String _ghBase =
      'https://raw.githubusercontent.com/Scaloart/Aviation/main/DA42%20VI/DOCUMENTS/';

  // Title to filename mapping for maintainability (named records)
  static const List<({String title, String file})> _docFiles = [
    (title: 'AFM DA42', file: 'AFM DA42.pdf'),
    (title: 'AIRSPEED DA42', file: 'AIRSPEED DA42.pdf'),
    (title: 'DA42 Checklist', file: 'DA42 Checklist.pdf'),
    (title: 'DA42 HANDBOOK', file: 'DA42 HANDBOOK.pdf'),
    (title: 'DA42 Systems Handout', file: 'DA42 Systems Handout.pdf'),
    (title: 'STANDARDIZED BRIEFINGS - DA42', file: 'STANDARDIZED BRIEFINGS - DA42.pdf'),
  ];

  // Built list of documents
  late final List<Document> _allDocuments = _docFiles
      .map((e) => Document(
            title: e.title,
            url: '$_ghBase${Uri.encodeComponent(e.file)}',
          ))
      .toList();
  List<Document> _filteredDocuments = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _filteredDocuments = _allDocuments;
    _searchController.addListener(_filterDocuments);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterDocuments() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredDocuments = _allDocuments.where((d) => d.title.toLowerCase().contains(q)).toList();
    });
  }

  // No local scanning; list is static

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
                    hintText: 'Search…',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(color: Colors.white),
                )
              : Text('DA42 VI Documents', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
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
        body: _filteredDocuments.isEmpty
            ? const Center(
                child: Text(
                  'No DA42 documents yet. Upload to GitHub and add URLs here.',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
                    if (isMobile) {
                      const double spacing = 16;
                      final double available = constraints.maxWidth;
                      // Two columns min on mobile
                      final double itemWidth = ((available - spacing) / 2).clamp(140.0, 260.0);
                      return Wrap(
                        spacing: spacing,
                        runSpacing: 16,
                        alignment: WrapAlignment.center,
                        children: _filteredDocuments
                            .map((doc) => SizedBox(width: itemWidth, height: 220, child: _PdfItem(document: doc)))
                            .toList(),
                      );
                    }
                    // Desktop/Web/Windows: keep previous layout
                    return Center(
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        alignment: WrapAlignment.center,
                        children: _filteredDocuments
                            .map((doc) => SizedBox(width: 160, height: 220, child: _PdfItem(document: doc)))
                            .toList(),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _PdfItem extends StatefulWidget {
  final Document document;
  const _PdfItem({super.key, required this.document});

  @override
  State<_PdfItem> createState() => _PdfItemState();
}

class _PdfItemState extends State<_PdfItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.identity()..scale(_hover ? 1.05 : 1.0),
        transformAlignment: Alignment.center,
        child: GestureDetector(
          onTap: () async {
            if (widget.document.url.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('URL not set yet for this document.')),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PdfViewerScreen(
                  url: widget.document.url,
                  title: widget.document.title,
                ),
              ),
            );
          },
          child: Column(
            children: [
              Expanded(
                child: Image.asset('assets/pdf poster.png', fit: BoxFit.contain),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: Text(
                  widget.document.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lato(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

