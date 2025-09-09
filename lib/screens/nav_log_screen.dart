import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:typed_data';
import 'package:brie_fly/models/notam_model.dart';
import 'package:brie_fly/models/temsi_chart_model.dart';
import 'package:brie_fly/models/wintem_chart_model.dart';
import 'package:brie_fly/services/navigation_service.dart';
import 'package:brie_fly/widgets/app_window_bar.dart';
import 'package:brie_fly/widgets/ad_pdf_viewer.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';

class NavLogScreen extends StatefulWidget {
  final List<String> selectedItems;
  final String airportCodes;
  final String? navLogPath;
  final Uint8List? navLogBytes;
  final String? flightPlanPath;
  final Uint8List? flightPlanBytes;
  final Uint8List? balanceSheetBytes;
  final List<SelectedTemsiChart> selectedTemsiCharts;
  final List<SelectedWintemChart> selectedWintemCharts;
  final List<Notam> notams;

  const NavLogScreen({
    Key? key,
    required this.selectedItems,
    required this.airportCodes,
    this.navLogPath,
    this.navLogBytes,
    this.flightPlanPath,
    this.flightPlanBytes,
    this.balanceSheetBytes,
    this.selectedTemsiCharts = const [],
    this.selectedWintemCharts = const [],
    this.notams = const [],
  }) : super(key: key);

  @override
  State<NavLogScreen> createState() => _NavLogScreenState();
}

class _NavLogScreenState extends State<NavLogScreen> {
  
  @override
  void initState() {
    super.initState();
        _importedPdfFile = widget.navLogPath != null ? File(widget.navLogPath!) : null;
    _importedPdfBytes = widget.navLogBytes;
  }

  Widget _buildNavigationButtons(BuildContext context) {
    final bool isLast = NavigationService.isLastScreen('LOG de Navigation', widget.selectedItems);
    return SafeArea(
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: <Widget>[
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
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  final route = NavigationService.getNextScreenRoute(
                    context: context,
                    currentScreen: 'LOG de Navigation',
                    selectedItems: widget.selectedItems,
                    airportCodes: widget.airportCodes,
                    navLogPath: _importedPdfFile?.path,
                    navLogBytes: _importedPdfBytes,
                    flightPlanPath: widget.flightPlanPath,
                    flightPlanBytes: widget.flightPlanBytes,
                    balanceSheetBytes: widget.balanceSheetBytes,
                    selectedTemsiCharts: widget.selectedTemsiCharts,
                    selectedWintemCharts: widget.selectedWintemCharts,
                    notams: widget.notams,
                  );
                  if (route != null) {
                    Navigator.of(context).push(route);
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
      ),
    );
  }
  File? _importedPdfFile;
  Uint8List? _importedPdfBytes;

  Future<void> _downloadLog() async {
    try {
      final byteData = await rootBundle.load('assets/templates/Nav LOG.xlsx');
      final buffer = byteData.buffer.asUint8List();

      // On mobile, bytes must be passed directly to saveFile.
      // On desktop, this will still work correctly.
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Excel Log As...',
        fileName: 'Nav_LOG.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: buffer, // Pass bytes directly for mobile compatibility
      );

      if (outputFile != null) {
        // On mobile, outputFile is null, but the file is saved.
        // On desktop, outputFile is the path.
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log downloaded successfully!')),
        );
      } else {
        // User canceled the picker
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download canceled.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading log: $e')),
      );
    }
  }

  Future<void> _importLog() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        setState(() {
          _importedPdfFile = file; // Keep the file for its path
          _importedPdfBytes = bytes; // Store bytes for the viewer
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing log: $e')),
      );
    }
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
                padding: EdgeInsets.fromLTRB(24.0, 24.0 + (isDesktop ? AppWindowBar.height : 0), 24.0, 24.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Text(
                            'LOG de Navigation',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildOptionButton(
                      context,
                      icon: Icons.download_for_offline,
                      label: 'Download Excel LOG',
                      onPressed: _downloadLog,
                      isPrimary: true,
                    ),
                    const SizedBox(height: 24),
                    _buildOptionButton(
                      context,
                      icon: Icons.upload_file_outlined,
                      label: 'Import PDF for Preview',
                      onPressed: _importLog,
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                    _buildPdfPreview(),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildNavigationButtons(context),
      ),
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

  Widget _buildPdfPreview() {
    return Expanded(
      child: _importedPdfBytes == null
          ? Center(
              child: Text(
                'Import a PDF to preview it here.',
                style: GoogleFonts.montserrat(fontSize: 16, color: Colors.grey.shade700),
              ),
            )
          : AdPdfViewer.data(
              _importedPdfBytes!,
              sourceName: 'nav_log.pdf',
            ),
    );
  }
}

