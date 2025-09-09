import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:brie_fly/screens/pdf_viewer_screen.dart';

class Document {
  final String title;
  final String url; // Can be empty for now; fill when files are uploaded

  Document({required this.title, required this.url});
}

class DA42DocumentsScreen extends StatefulWidget {
  const DA42DocumentsScreen({super.key});

  @override
  State<DA42DocumentsScreen> createState() => _DA42DocumentsScreenState();
}

class _DA42DocumentsScreenState extends State<DA42DocumentsScreen> {
  // TODO: Fill this list with actual file titles and URLs once uploaded to GitHub
  // Example placeholder entries based on "C:\\Users\\slwdw\\Desktop\\Media For app\\DA42 VI"
  final List<Document> _allDocuments = [
    // Document(title: 'AFM DA42 VI', url: 'https://raw.githubusercontent.com/<yourrepo>/DA42%20VI/AFM%20DA42%20VI.pdf'),
    // Document(title: 'DA42 VI AMM', url: 'https://raw.githubusercontent.com/<yourrepo>/DA42%20VI/DA42%20VI%20AMM.pdf'),
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
                  if (!_isSearching) {
                    _searchController.clear();
                  }
                });
              },
            ),
          ],
        ),
        body: _filteredDocuments.isEmpty
            ? const Center(
                child: Text(
                  'No documents yet. Upload files to GitHub and add their titles/URLs here.',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
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
                          return _PdfThumbnailItem(document: doc);
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _PdfThumbnailItem extends StatefulWidget {
  final Document document;
  const _PdfThumbnailItem({Key? key, required this.document}) : super(key: key);

  @override
  State<_PdfThumbnailItem> createState() => _PdfThumbnailItemState();
}

class _PdfThumbnailItemState extends State<_PdfThumbnailItem> {
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
            if (widget.document.url.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('URL not set yet for this document.')),
              );
              return;
            }
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
              SizedBox(
                height: 40,
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

