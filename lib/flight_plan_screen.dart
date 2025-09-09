import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:brie_fly/services/navigation_service.dart';
import 'package:brie_fly/widgets/ad_pdf_viewer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:brie_fly/widgets/app_window_bar.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';

import '../models/temsi_chart_model.dart';
import 'package:brie_fly/models/wintem_chart_model.dart';
import 'package:brie_fly/models/notam_model.dart';

class FlightPlanScreen extends StatefulWidget {
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

  const FlightPlanScreen({
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
  State<FlightPlanScreen> createState() => _FlightPlanScreenState();
}

class _FlightPlanScreenState extends State<FlightPlanScreen> {
  String? _flightPlanPath;
  Uint8List? _flightPlanBytes;

  @override
  void initState() {
    super.initState();
    _flightPlanPath = widget.flightPlanPath;
    _flightPlanBytes = widget.flightPlanBytes;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.macOS);
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        iconTheme: const IconThemeData(color: Colors.black87),
        textTheme: GoogleFonts.montserratTextTheme(ThemeData.light().textTheme)
            .apply(bodyColor: Colors.black87, displayColor: Colors.black87),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Stack(
          children: [
            if (isDesktop)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AppWindowBar(
                  buttonColors: WindowButtonColors(
                    iconNormal: Colors.black87,
                    iconMouseOver: Colors.black,
                    iconMouseDown: Colors.black,
                    mouseOver: Colors.black12,
                    mouseDown: Colors.black26,
                  ),
                  closeButtonColors: WindowButtonColors(
                    iconNormal: Colors.black87,
                    iconMouseOver: Colors.white,
                    mouseOver: const Color(0xFFE57373),
                    mouseDown: const Color(0xFFD32F2F),
                  ),
                ),
              ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.0, 16.0 + (isDesktop ? AppWindowBar.height : 0), 16.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Text(
                            'Plan de Vol',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 26, color: Colors.black87),
                          ),
                        ),
                        if (_flightPlanPath != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Clear Selection',
                            onPressed: () {
                              setState(() {
                                _flightPlanPath = null;
                              });
                            },
                          )
                        else
                          const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: _flightPlanPath == null
                            ? _buildOptionSelector()
                            : _buildPdfPreview(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfPreview() {
    return Column(
      children: [
        Expanded(
          child: _flightPlanBytes == null
              ? Center(
                  child: Text(
                    'No flight plan selected.',
                    style: GoogleFonts.montserrat(
                        fontSize: 16, color: Colors.grey.shade700),
                  ),
                )
              : AdPdfViewer.data(
                  _flightPlanBytes!,
                  sourceName: 'flight_plan.pdf',
                ),
        ),
        const SizedBox(height: 16),
        _buildNavigationButtons(context),
      ],
    );
  }

  Widget _buildOptionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        const SizedBox(height: 16),
        _buildOptionButton(
          context,
          icon: Icons.upload_file,
          label: 'Import My Own Flight Plan',
          onPressed: () => _pickFlightPlanFile(context),
          isPrimary: true,
        ),
        const SizedBox(height: 24),
        _buildOptionButton(
          context,
          icon: Icons.language,
          label: 'Use Center’s EuroFPL Account',
          onPressed: _launchEuroFplUrl,
        ),

        const Spacer(),
        _buildNavigationButtons(context),
      ],
    );
  }

  Widget _buildOptionButton(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onPressed,
      bool isPrimary = false}) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 28),
      label: Text(label,
          style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600)),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? const Color(0xFF1976D2) : Colors.white,
        foregroundColor: isPrimary ? Colors.white : const Color(0xFF1976D2),
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: isPrimary ? Colors.transparent : const Color(0xFF1976D2),
              width: 2),
        ),
        elevation: 2,
      ),
    );
  }

  Future<void> _launchEuroFplUrl() async {
    final Uri url = Uri.parse('https://www.eurofpl.eu/');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch URL')),
      );
    }
  }



  Future<void> _pickFlightPlanFile(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      setState(() {
        _flightPlanPath = result.files.single.path!;
        _flightPlanBytes = bytes;
      });
    } else {
      print('User canceled file picking or file path was null.');
    }
  }

  Widget _buildNavigationButtons(BuildContext context) {
    bool isLast = NavigationService.isLastScreen('Plan de Vol', widget.selectedItems);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade300,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Quitter',
                style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                final route = NavigationService.getNextScreenRoute(
                  context: context,
                  currentScreen: 'Plan de Vol',
                  selectedItems: widget.selectedItems,
                  airportCodes: widget.airportCodes,
                  navLogPath: widget.navLogPath,
                  navLogBytes: widget.navLogBytes,
                  flightPlanPath: _flightPlanPath,
                  flightPlanBytes: _flightPlanBytes,
                  balanceSheetBytes: widget.balanceSheetBytes,
                  selectedTemsiCharts: widget.selectedTemsiCharts,
                  selectedWintemCharts: widget.selectedWintemCharts,
                  notams: widget.notams,
                );
                if (route != null) {
                  Navigator.push(context, route);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isLast ? 'Generate Dossier' : 'Continue',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

