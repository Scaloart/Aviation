import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:brie_fly/widgets/background_container.dart';
import 'package:brie_fly/screens/pdf_viewer_screen.dart';

class Arrete {
  final String title;
  final String originalFileName;

  Arrete({required this.title, required this.originalFileName});
}

class ArretesListScreen extends StatefulWidget {
  const ArretesListScreen({super.key});

  @override
  State<ArretesListScreen> createState() => _ArretesListScreenState();
}

class _ArretesListScreenState extends State<ArretesListScreen> {
  late final List<Arrete> _allArretes;
  List<Arrete> _filteredArretes = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  final List<String> _fileNames = [
      "Ar218-96_Programme et régime d_examens ATPL.pdf",
      "Arr1150-05_Immatriculation des aéronefs.pdf",
      "Arr1390-02_Equipements généraux et spécifiques des aéronefs.pdf",
      "Arr1397-02_Conditions d_exploitation à observer par PNT PNC et ATE.pdf",
      "Arr1460-02_Performances des aéronefs.pdf",
      "Arr1655-12_Plan de Vol.pdf",
      "Arr219-96_Programme et régime d_examen IR.pdf",
      "Arr2662-09_Surfaces de limitation d_obstacles.pdf",
      "Arr3066-97_Programme et régime d_examen PPL.pdf",
      "Arr3163-12_Licences et qualifications des membres d_équipages de conduite.pdf",
      "Arr3282-13_Services de la circulation aérienne.pdf",
      "Arr3283-13_Règles de l_air.pdf",
      "Arr335-95_Programme et régime d_examen CPL.pdf",
      "Arr3761-13_Service d_information aéronautique.pdf",
      "Arr3762-13_Cartes aéronautiques.pdf",
      "Arr544-00_Obtention de l_autorisation d_exploitation des services aériens de transport public et de travail aérien.pdf",
      "Arr545-72_Conditions de navigabilité des aéronefs civils.pdf",
      "Arr780-03_Transport des marchandises dangereuses.pdf",
      "Arr926-08_Durée du travail du personnel navigant professionnel.pdf",
      "Arr948-02_Préparation et éxecution des vols.pdf",
      "Arrete-227-97-licence-et-qualif-du-personnel.pdf",
      "Cir1575_Aides visuelles_Signalisations dans les aéroports.pdf",
      "Cir175_Délivrance et renouvellement CDN-CLN.pdf",
      "Cir189-00_Manuels d_exploitation et d_activités de  travail aérien.pdf",
      "Cir1891-03_Homologation des programmes de formation du personnel aéronautique.pdf",
      "Cir1892_Système qualité d_un organisme de formation.pdf",
      "Cir1913_Compétence liniguistique PNT.pdf",
      "Cir2217_RVSM.pdf",
      "Cir2257_MEL.pdf",
      "Cir2517_Distances déclarées des pistes d_envol.pdf",
      "Cir2537_Masse et centrage.pdf",
      "Cir26-09_Procédures.pdf",
      "Cir428-03_Système qualité d_un exploitant des services aériens.pdf",
      "Cir99-02_Approbation de l_exploitation ETOPS.pdf",
      "Décret2-61-161_Réglemenetation de l_aéronautique civile.pdf",
      "IT0721_Mise en place d_un système de gestion de la sécurité.pdf",
      "IT162-90_CATII-III.pdf",
      "IT1654_Agrément des organismes de formation.pdf",
      "IT1694_Exploitation des aéronefs dans l_aviation générale.pdf",
      "IT1726_Procédures de radiotéléphonie.pdf",
      "IT1726_Prévention et lutte contre le risque animalier.pdf",
      "IT1728_Notification et analyse des événements.pdf",
      "IT1845_Service de sauvetage et lutte contre les incendies des aéronefs.pdf",
      "IT1876_Risque aviaire.pdf",
      "IT2092_Enquête acccidents et incidents d_aviation civile.pdf",
      "IT2943_Caractéristiques physiques des aérodromes civils.pdf",
      "IT3846_Contrôle des obstacles.pdf",
      "PROCEDURE DE CONDUITE DES CONTROLES EN VOL.pdf"
  ];

  @override
  void initState() {
    super.initState();
    _allArretes = _fileNames.map((fileName) => Arrete(title: _formatTitle(fileName), originalFileName: fileName)).toList();
    _filteredArretes = _allArretes;
    _searchController.addListener(_filterArretes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterArretes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredArretes = _allArretes.where((arrete) {
        return arrete.title.toLowerCase().contains(query);
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
              : Text('ARRETES', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
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
                    itemCount: _filteredArretes.length,
                    itemBuilder: (context, index) {
                      final arrete = _filteredArretes[index];
                      return PdfThumbnailItem(arrete: arrete);
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
                  children: _filteredArretes
                      .map((arrete) => SizedBox(
                            width: 160,
                            height: 220,
                            child: PdfThumbnailItem(arrete: arrete),
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
  final Arrete arrete;

  const PdfThumbnailItem({Key? key, required this.arrete}) : super(key: key);

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
            final String baseUrl = 'https://raw.githubusercontent.com/Scaloart/Aviation/main/documents/Arretes/';
            final String pdfUrl = '$baseUrl${Uri.encodeComponent(widget.arrete.originalFileName)}';
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PdfViewerScreen(url: pdfUrl, title: widget.arrete.title),
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
                  widget.arrete.title,
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

