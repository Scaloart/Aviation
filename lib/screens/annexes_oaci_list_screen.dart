import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:brie_fly/widgets/background_container.dart';
import 'package:brie_fly/screens/pdf_viewer_screen.dart';

class AnnexeOaci {
  final String title;
  final String originalFileName;

  AnnexeOaci({required this.title, required this.originalFileName});
}

class AnnexesOaciListScreen extends StatefulWidget {
  const AnnexesOaciListScreen({super.key});

  @override
  State<AnnexesOaciListScreen> createState() => _AnnexesOaciListScreenState();
}

class _AnnexesOaciListScreenState extends State<AnnexesOaciListScreen> {
  late final List<AnnexeOaci> _allAnnexes;
  List<AnnexeOaci> _filteredAnnexes = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  final List<String> _fileNames = [
    "ANNEXE 1 LICENCES DU PERSONNEL.pdf",
    "ANNEXE 2 RÈGLES DE L'AIR.pdf",
    "ANNEXE 3 MÉTÉO.pdf",
    "ANNEXE 4 CARTES AÉRONAUTIQUES.pdf",
    "ANNEXE 5 UNITÉ DE MESURE À UTILISER DANS L'EXPLOITATION EN.pdf",
    "ANNEXE 6 EXPLOITATION TECHNIQUE DES AÉRONEFS PARTIE 1.pdf",
    "ANNEXE 6 EXPLOITATION TECHNIQUE DES AÉRONEFS PARTIE 2.pdf",
    "ANNEXE 6 EXPLOITATION TECHNIQUE DES AÉRONEFS PARTIE 3.pdf",
    "ANNEXE 7 MARQUES DE NATIONALITÉ ET D'IMMATRICULATION DES AÉ.pdf",
    "ANNEXE 8 NAVIGABILITÉ DES AÉRONEFS.pdf",
    "ANNEXE 9 FACILITATION.pdf",
    "ANNEXE 9 FACILITATION supplément.pdf",
    "ANNEXE 10 TELECOMMUNICATION AERONAUTIQUE VOLUME I.pdf",
    "ANNEXE 10 TELECOMMUNICATION AERONAUTIQUE VOLUME II.pdf",
    "ANNEXE 10 TELECOMMUNICATION AERONAUTIQUE VOLUME III.pdf",
    "ANNEXE 10 TELECOMMUNICATION AERONAUTIQUE VOLUME IV.pdf",
    "ANNEXE 10 TELECOMMUNICATION AERONAUTIQUE VOLUME V.pdf",
    "ANNEXE 11 SERVICES DE LA CIRCULATION AÉRIENNE.pdf",
    "ANNEXE 12 RECHERCHE ET SAUVETAGE.pdf",
    "ANNEXE 13 ENQUÊTES SUR LES ACCIDENTS ET INCIDENTS D'AÈRONEF.pdf",
    "ANNEXE 14 AERODROMES VOLUME I.pdf",
    "ANNEXE 14 AERODROMES VOLUME II.pdf",
    "ANNEXE 15 SERVICES D'INFORMATION AERONAUTIQUE.pdf",
    "ANNEXE 16 PROTECTION DE L'ENVIRONNEMENT VOLUME I.pdf",
    "ANNEXE 16 PROTECTION DE L'ENVIRONNEMENT VOLUME II.pdf",
    "ANNEXE 16 PROTECTION DE L'ENVIRONNEMENT VOLUME III.pdf",
    "ANNEXE 16 PROTECTION DE L'ENVIRONNEMENT VOLUME IV.pdf",
    "ANNEXE 17 SURETE.pdf",
    "ANNEXE 18 SECURITE DU TRANSPORT AERIEN DES MARCHANDISES DANGEREUSES.pdf",
    "ANNEXE 18 SÉCURITÉ DU TRANSPORT DES MARCHANDISES DANGEREUSES.pdf",
    "ANNEXE 19 GESTION DE LA SECURITE.pdf"
  ];

  @override
  void initState() {
    super.initState();
    _allAnnexes = _fileNames.map((fileName) => AnnexeOaci(title: _formatTitle(fileName), originalFileName: fileName)).toList();
    _filteredAnnexes = _allAnnexes;
    _searchController.addListener(_filterAnnexes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterAnnexes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredAnnexes = _allAnnexes.where((annexe) {
        return annexe.title.toLowerCase().contains(query);
      }).toList();
    });
  }

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
              : Text('ANNEXES OACI', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
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
                    itemCount: _filteredAnnexes.length,
                    itemBuilder: (context, index) {
                      final annexe = _filteredAnnexes[index];
                      return PdfThumbnailItem(annexe: annexe);
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
                  children: _filteredAnnexes
                      .map((annexe) => SizedBox(
                            width: 160,
                            height: 220,
                            child: PdfThumbnailItem(annexe: annexe),
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
  final AnnexeOaci annexe;

  const PdfThumbnailItem({Key? key, required this.annexe}) : super(key: key);

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
            final String baseUrl = 'https://raw.githubusercontent.com/Scaloart/Aviation/main/documents/Annexes%20OACI/';
            final String pdfUrl = '$baseUrl${Uri.encodeComponent(widget.annexe.originalFileName)}';
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PdfViewerScreen(url: pdfUrl, title: widget.annexe.title),
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
                  widget.annexe.title,
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

