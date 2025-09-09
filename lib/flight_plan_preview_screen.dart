import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'screens/generated_dossier_screen.dart';
import '../models/temsi_chart_model.dart';
import '../models/wintem_chart_model.dart';

class FlightPlanPreviewScreen extends StatelessWidget {
  final String filePath;
  final List<String> selectedItems;
  final String airportCodes;
  final List<SelectedTemsiChart> selectedTemsiCharts;
  final List<SelectedWintemChart> selectedWintemCharts;

  const FlightPlanPreviewScreen({
    Key? key,
    required this.filePath,
    required this.selectedItems,
    required this.airportCodes,
    required this.selectedTemsiCharts,
    required this.selectedWintemCharts,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(filePath);
    final fileExtension = p.extension(filePath).toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(fileName, style: GoogleFonts.poppins()),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: _buildContentView(fileExtension),
      bottomNavigationBar: _buildNavigationButtons(context),
    );
  }

  Widget _buildContentView(String extension) {
    if (extension == '.pdf') {
      return PDFView(
        filePath: filePath,
      );
    } else if (['.jpg', '.jpeg', '.png'].contains(extension)) {
      return Center(
        child: InteractiveViewer(
          child: Image.file(File(filePath)),
        ),
      );
    } else {
      return const Center(
        child: Text('Unsupported file format'),
      );
    }
  }

  Widget _buildNavigationButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blueGrey[900],
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Back',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => GeneratedDossierScreen(
                    selectedItems: selectedItems,
                    airportCodes: airportCodes,
                    selectedTemsiCharts: selectedTemsiCharts,
                    selectedWintemCharts: selectedWintemCharts,
                    flightPlanPath: filePath,
                  ),
                ),
                (Route<dynamic> route) => route.isFirst,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Save to Dossier',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
