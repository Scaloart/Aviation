import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:brie_fly/screens/pdf_viewer_screen.dart';

class ResumeDoc {
  final String title;
  final String originalFileName;

  ResumeDoc({required this.title, required this.originalFileName});
}

class ResumesScreen extends StatefulWidget {
  const ResumesScreen({super.key});

  @override
  State<ResumesScreen> createState() => _ResumesScreenState();
}

class _ResumesScreenState extends State<ResumesScreen> {
  // Adjust this to your repo path if different
  static const String _githubBaseUrl =
      'https://raw.githubusercontent.com/Scaloart/Aviation/main/Resumes/';

  // Permanent list of resume filenames stored in the GitHub repository
  static const List<String> _fileNames = [
    'Approches IFR.pdf',
    'Attente.pdf',
    'CPL PRATIQUE TEST.pdf',
    'EN ROUTE.pdf',
    'Info CPL.pdf',
    'METEO CPL.pdf',
    'Questions de briefing.pdf',
    'REGLEMENTATION CPL.pdf',
    "Règles de l'air IFR.pdf",
    'Résumé Reglementation.pdf',
    'SID.pdf',
    'Turbulence.pdf',
  ];

  late List<ResumeDoc> _allResumes;
  List<ResumeDoc> _filteredResumes = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _allResumes = _fileNames
        .map((name) => ResumeDoc(title: _formatTitle(name), originalFileName: name))
        .toList();
    _filteredResumes = _allResumes;
    _searchController.addListener(_filterResumes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterResumes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredResumes = _allResumes
          .where((d) => d.title.toLowerCase().contains(query))
          .toList();
    });
  }

  // Removed local folder loading; using static list instead.

  String _formatTitle(String fileName) {
    return fileName.replaceAll('_', ' ').replaceAll('.pdf', '');
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
              : Text('RESUMES',
                  style: GoogleFonts.montserrat(
                      color: Colors.white, fontWeight: FontWeight.bold)),
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
                    itemCount: _filteredResumes.length,
                    itemBuilder: (context, index) {
                      final doc = _filteredResumes[index];
                      return _PdfThumbResumeItem(doc: doc, githubBaseUrl: _githubBaseUrl);
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
                  children: _filteredResumes
                      .map((doc) => SizedBox(
                            width: 160,
                            height: 220,
                            child: _PdfThumbResumeItem(doc: doc, githubBaseUrl: _githubBaseUrl),
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

class _PdfThumbResumeItem extends StatefulWidget {
  final ResumeDoc doc;
  final String githubBaseUrl;

  const _PdfThumbResumeItem({Key? key, required this.doc, required this.githubBaseUrl})
      : super(key: key);

  @override
  State<_PdfThumbResumeItem> createState() => _PdfThumbResumeItemState();
}

class _PdfThumbResumeItemState extends State<_PdfThumbResumeItem> {
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
            final String encodedName = Uri.encodeComponent(widget.doc.originalFileName);
            final String pdfUrl = '${widget.githubBaseUrl}$encodedName';
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PdfViewerScreen(
                  url: pdfUrl,
                  title: widget.doc.title,
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
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  widget.doc.title,
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

