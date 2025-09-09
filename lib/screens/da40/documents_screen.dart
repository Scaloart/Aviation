import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:brie_fly/screens/pdf_viewer_screen.dart';

class Document {
  final String title;
  final String url;

  Document({required this.title, required this.url});
}

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final List<Document> _allDocuments = [
    Document(title: 'AFM DA40 NG', url: 'https://raw.githubusercontent.com/Scaloart/Aviation/main/DA40%20NG/DOCUMENTS/AFM%20DA40%20NG.pdf'),
    Document(title: 'DA40 NG AMM', url: 'https://ia600900.us.archive.org/15/items/da-40-ng-amm/DA40%20NG%20AMM.pdf'),
    Document(title: 'DA40 NG Checklist', url: 'https://raw.githubusercontent.com/Scaloart/Aviation/main/DA40%20NG/DOCUMENTS/DA40%20NG%20Checklist.pdf'),
    Document(title: 'Handout DA40 NG Systems', url: 'https://raw.githubusercontent.com/Scaloart/Aviation/main/DA40%20NG/DOCUMENTS/Handout%20DA40%20NG%20Systems.pdf'),
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
              : Text('Documents', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
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
            final bool isMobile = !kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.iOS ||
                    defaultTargetPlatform == TargetPlatform.android);
            if (isMobile) {
              final int columns = (constraints.maxWidth ~/ 200).clamp(2, 8);
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: GridView.builder(
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
                  ),
                ),
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
                      .map((doc) => SizedBox(
                            width: 160,
                            height: 220,
                            child: PdfThumbnailItem(document: doc),
                          ))
                      .toList(),
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
                builder: (context) => PdfViewerScreen(url: widget.document.url, title: widget.document.title),
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

