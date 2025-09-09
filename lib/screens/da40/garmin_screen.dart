import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:brie_fly/screens/pdf_viewer_screen.dart';

class Document {
  final String title;
  final String url;

  Document({required this.title, required this.url});
}

class GarminScreen extends StatefulWidget {
  const GarminScreen({super.key});

  @override
  State<GarminScreen> createState() => _GarminScreenState();
}

class _GarminScreenState extends State<GarminScreen> {
  final List<Document> _allDocuments = [
    Document(title: 'Garmin DA40 NG G1000 NXi Cockpit Reference Guide', url: 'https://raw.githubusercontent.com/Scaloart/Aviation/main/DA40%20NG/GARMIN/Garmin%20DA40%20NG%20G1000%20NXi%20Cockpit%20Reference%20Guide.pdf'),
    Document(title: 'Garmin DA40 NG G1000 NXi Pilot\'s Guide', url: 'https://archive.org/download/garmin-da-40-ng-g-1000-nxi-pilots-guide/Garmin%20DA40%20NG%20G1000%20NXi%20Pilot%27s%20Guide.pdf'),
    Document(title: 'Handout Garmin G1000 Part 1', url: 'https://raw.githubusercontent.com/Scaloart/Aviation/main/DA40%20NG/GARMIN/Handout%20Garmin%20G1000%20Part%201.pdf'),
    Document(title: 'Handout Garmin G1000 Part 2 The System', url: 'https://raw.githubusercontent.com/Scaloart/Aviation/main/DA40%20NG/GARMIN/Handout%20Garmin%20G1000%20Part%202%20The%20System.pdf'),
    Document(title: 'Handout Garmin G1000 Part 3 VFR', url: 'https://raw.githubusercontent.com/Scaloart/Aviation/main/DA40%20NG/GARMIN/Handout%20Garmin%20G1000%20Part%203%20VFR.pdf'),
  ];

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
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDocuments = _allDocuments.where((doc) {
        return doc.title.toLowerCase().contains(query);
      }).toList();
    });
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
              : Text('GARMIN', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  if (!_isSearching) {
                    _searchController.clear();
                  }
                });
              },
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
            if (isMobile) {
              final int columns = (constraints.maxWidth ~/ 200).clamp(2, 8);
              return GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  childAspectRatio: 160 / 220,
                ),
                itemCount: _filteredDocuments.length,
                itemBuilder: (context, index) {
                  final doc = _filteredDocuments[index];
                  return PdfThumbnailItem(document: doc);
                },
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  alignment: WrapAlignment.center,
                  children: _filteredDocuments
                      .map((doc) => const SizedBox(width: 160, height: 220))
                      .toList()
                      .asMap()
                      .entries
                      .map((entry) {
                    final index = entry.key;
                    final _ = entry.value; // placeholder
                    final doc = _filteredDocuments[index];
                    return SizedBox(
                      width: 160,
                      height: 220,
                      child: PdfThumbnailItem(document: doc),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class PdfThumbnailItem extends StatefulWidget {
  final Document document;

  const PdfThumbnailItem({Key? key, required this.document}) : super(key: key);

  @override
  _PdfThumbnailItemState createState() => _PdfThumbnailItemState();
}

class _PdfThumbnailItemState extends State<PdfThumbnailItem> {
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
          onTap: () async {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PdfViewerScreen(
                  url: widget.document.url,
                  title: widget.document.title,
                ),
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: Image.asset(
                  'assets/pdf poster.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 40, // Fixed height for 2 lines of text
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  widget.document.title,
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
}

