import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:brie_fly/models/notam_model.dart';
import 'package:brie_fly/models/temsi_chart_model.dart';
import 'package:brie_fly/models/wintem_chart_model.dart';
import 'package:brie_fly/services/pdf_service.dart';
import 'package:brie_fly/services/dossier_service.dart';
import 'package:brie_fly/models/dossier_info.dart';
import 'package:path_provider/path_provider.dart';
import 'dossiers_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brie_fly/services/cloud_dossier_service.dart';
import 'package:brie_fly/widgets/app_window_bar.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';

class GeneratedDossierScreen extends StatefulWidget {
  final List<String> selectedItems;
  final String airportCodes;
  final List<SelectedTemsiChart> selectedTemsiCharts;
  final List<SelectedWintemChart> selectedWintemCharts;
  final List<Notam> notams;
  final String? navLogPath;
  final Uint8List? navLogBytes;
  final String? flightPlanPath;
  final Uint8List? flightPlanBytes;
  final Uint8List? balanceSheetBytes;

  const GeneratedDossierScreen({
    Key? key,
    required this.selectedItems,
    required this.airportCodes,
    required this.selectedTemsiCharts,
    required this.selectedWintemCharts,
    required this.notams,
    this.navLogPath,
    this.navLogBytes,
    this.flightPlanPath,
    this.flightPlanBytes,
    this.balanceSheetBytes,
  }) : super(key: key);

  @override
  _GeneratedDossierScreenState createState() => _GeneratedDossierScreenState();
}

class _GeneratedDossierScreenState extends State<GeneratedDossierScreen> {
  final PdfService _pdfService = PdfService();
  final DossierService _dossierService = DossierService();
  final CloudDossierService _cloud = CloudDossierService();
  bool _isGenerating = true;

  @override
  void initState() {
    super.initState();
    _initPdfGeneration();
  }

  Future<File> _initPdfGeneration() async {
    try {
      final airports = widget.airportCodes.split(',').where((s) => s.isNotEmpty).toList();
      final opmetResult = await _pdfService.fetchOpmetsForDebug(airports);
      final file = await _generatePdf(opmetResult);

      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
        // Navigate to DossiersScreen and show success dialog there
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DossiersScreen(showSuccess: true)),
          (route) => route.isFirst,
        );
      }
      return file;
    } catch (e, s) {
      print('Error during PDF initialization: $e\n$s');
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
        // Optionally, show an error dialog
      }
      rethrow;
    }
  }

  Future<File> _generatePdf(Map<String, dynamic> opmetResult) async {
    try {
      await initializeDateFormatting('fr_FR', null);
      final airports = widget.airportCodes.split(',').where((s) => s.trim().isNotEmpty).toList();
      final departure = airports.isNotEmpty ? airports.first : '';
      final arrival = airports.length > 1 ? airports[1] : '';
      final enRoute = airports.length > 2 ? airports.sublist(2).join(' - ') : '';

      const flightNumber = '29035';
      const category = 'NATIONAL';

      final dossierNumber = '$flightNumber-$departure,$arrival-${DateTime.now().millisecondsSinceEpoch}';
      final pdfDossierNumber = '$departure,$arrival'; // Version without prefix for PDF
      final via = enRoute.isNotEmpty ? enRoute : '';

      final dossierFile = await _pdfService.generateDossierPdf(
        widget.airportCodes,
        widget.selectedTemsiCharts,
        widget.selectedWintemCharts,
        widget.notams,
        widget.navLogBytes,
        widget.flightPlanBytes,
        widget.balanceSheetBytes,
        pdfDossierNumber, // Use the version without prefix
        category,
        DateFormat('EEEE dd MMMM yyyy à HH:mm', 'fr_FR').format(DateTime.now()),
        '', // Pass empty string for qualityCode
        via,
        widget.selectedItems,
        opmetResult, // Pass fetched data here
      );

      final String dossierName;
      if (airports.length == 1) {
        dossierName = 'LOCAL FLIGHT';
      } else if (airports.length >= 2) {
        dossierName = '$departure - $arrival';
      } else {
        dossierName = 'N/A';
      }

      final dossierInfo = DossierInfo(
        id: dossierNumber,
        productionDate: DateTime.now(),
        name: dossierName,
        category: category,
        filePath: dossierFile.path,
        departAirportCodes: airports.isNotEmpty ? [airports.first] : [],
        arriveeAirportCodes: airports.length > 1 ? [airports[1]] : [],
        enRouteAirportCodes: airports.length > 2 ? airports.sublist(2) : [],
        selectedOptions: widget.selectedItems,
      );
      await _dossierService.saveDossierInfo(dossierInfo);

      // If signed in, upload to cloud in background
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        unawaited(_cloud.uploadDossier(uid: user.uid, file: dossierFile, info: dossierInfo));
      }

      return dossierFile;
    } catch (e, s) {
      print('Error generating PDF: $e');
      print('Stack trace: $s');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isDesktop = !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.macOS);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Full-screen gradient background (also visible behind window bar)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0B132B), Color(0xFF1C2541), Color(0xFF3A506B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          if (isDesktop)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppWindowBar(),
            ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(top: isDesktop ? AppWindowBar.height : 0),
              child: Center(
                child: _isGenerating
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Génération du dossier en cours...',
                            style: GoogleFonts.montserrat(fontSize: 16, color: Colors.white70),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _SuccessDialogContent(
              onClose: () {
                Navigator.of(dialogContext).popUntil((r) => r.isFirst);
              },
              onViewDossiers: () {
                Navigator.of(dialogContext).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const DossiersScreen()),
                  (r) => r.isFirst,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Private dialog widget with animation + branded visuals
class _SuccessDialogContent extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onViewDossiers;

  const _SuccessDialogContent({
    required this.onClose,
    required this.onViewDossiers,
  });

  @override
  State<_SuccessDialogContent> createState() => _SuccessDialogContentState();
}

class _SuccessDialogContentState extends State<_SuccessDialogContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..forward();

    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: FadeTransition(
        opacity: _opacity,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          backgroundColor: Colors.transparent,
          child: SafeArea(
            child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: 560,
            ),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _LogoBadge(),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _AnimatedCheckIcon(controller: _controller),
                      const SizedBox(width: 12),
                      Text(
                        'Dossier prêt',
                        style: GoogleFonts.montserrat(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        semanticsLabel: 'Dossier prêt',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Votre dossier de vol a été généré et sauvegardé avec succès.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    semanticsLabel:
                        'Votre dossier de vol a été généré et sauvegardé avec succès.',
                  ),
                  const SizedBox(height: 16),
                  const _InfoChip(),
                  const SizedBox(height: 24),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton(
                          onPressed: widget.onClose,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white.withOpacity(0.85),
                            side: BorderSide(color: Colors.white.withOpacity(0.6)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size(100, 44),
                          ),
                          child: Text(
                            'Fermer',
                            style: GoogleFonts.montserrat(),
                          ),
                        ),
                        FilledButton(
                          onPressed: widget.onViewDossiers,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size(140, 44),
                          ),
                          child: Text(
                            'Voir les dossiers',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

/// App logo badge with graceful fallback
class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Image.asset(
        'assets/Logos/logo.png',
        fit: BoxFit.contain,
        errorBuilder: (context, _, __) {
          // Try alternate path if folder differs
          return Image.asset(
            'assets/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, __, ___) {
              return Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'EPL3',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Small animated check icon
class _AnimatedCheckIcon extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedCheckIcon({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.6, end: 1.0)
          .animate(CurvedAnimation(parent: controller, curve: Curves.elasticOut)),
      child: const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 28),
    );
  }
}

/// Info chip/panel with folder icon
class _InfoChip extends StatelessWidget {
  const _InfoChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.folder_outlined, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Accédez à vos dossiers pour consulter, partager ou supprimer des fichiers.',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  color: Colors.white70,
                ),
                softWrap: true,
                textAlign: TextAlign.start,
                semanticsLabel:
                    'Accédez à vos dossiers pour consulter, partager ou supprimer des fichiers.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}



