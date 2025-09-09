import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:brie_fly/widgets/ad_pdf_viewer.dart';
import 'package:brie_fly/services/navigation_service.dart';
import 'package:brie_fly/models/notam_model.dart';
import 'package:brie_fly/models/temsi_chart_model.dart';
import 'package:brie_fly/models/wintem_chart_model.dart';

class BalanceSheetViewerScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final Uint8List? flightPlanBytes;
  final List<String> selectedItems;
  final String airportCodes;
  final String flightPlanPath;
  final List<SelectedTemsiChart> selectedTemsiCharts;
  final List<SelectedWintemChart> selectedWintemCharts;
  final List<Notam> notams;

  const BalanceSheetViewerScreen({
    Key? key,
    required this.pdfBytes,
    this.flightPlanBytes,
    required this.selectedItems,
    required this.airportCodes,
    required this.flightPlanPath,
    required this.selectedTemsiCharts,
    required this.selectedWintemCharts,
    required this.notams,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Balance Sheet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            tooltip: 'Continue',
            onPressed: () {
              final route = NavigationService.getNextScreenRoute(
                context: context,
                currentScreen: 'Balance Sheet',
                selectedItems: selectedItems,
                airportCodes: airportCodes,
                flightPlanPath: flightPlanPath,
                flightPlanBytes: flightPlanBytes,
                balanceSheetBytes: pdfBytes,
                selectedTemsiCharts: selectedTemsiCharts,
                selectedWintemCharts: selectedWintemCharts,
                notams: notams,
              );
              if (route != null) {
                Navigator.push(context, route);
              }
            },
          ),
        ],
      ),
      body: AdPdfViewer.data(
        pdfBytes,
        sourceName: 'balance_sheet.pdf',
      ),
    );
  }
}

