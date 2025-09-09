import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class BalanceSheetPdfService {
  Future<Uint8List> createBalanceSheetPdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    final aircraftType = data['aircraftType'] as String;
    final registration = data['registration'] as String;
    final results = data['results'] as Map<String, dynamic>;
    final envelopePoints = data['cgEnvelope'] as List<dynamic>;
    final chartImage = data['chartImage'] as Uint8List;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          final highLevelFont = pw.Font.helvetica();

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(aircraftType, registration),
              pw.SizedBox(height: 20),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // --- Left Column ---
                  pw.Expanded(
                    flex: 1,
                    child: _buildLoadAndSummaryColumn(data, results),
                  ),
                  pw.SizedBox(width: 20),
                  // --- Right Column ---
                  pw.Expanded(
                    flex: 1,
                    child: _buildChartColumn(envelopePoints, results, highLevelFont, context.canvas.defaultFont!, chartImage),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(String aircraftType, String registration) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Weight & Balance Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Text('Aircraft: $aircraftType ($registration)', style: const pw.TextStyle(fontSize: 16, color: PdfColors.grey700)),
        pw.SizedBox(height: 5),
        pw.Text('Date: ${DateTime.now().toLocal().toString().split(' ')[0]}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
        pw.Divider(height: 20, thickness: 1.5),
      ],
    );
  }

  pw.Widget _buildLoadAndSummaryColumn(Map<String, dynamic> data, Map<String, dynamic> results) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _buildLoadStationsTable(data, results),
        pw.SizedBox(height: 20),
        _buildSummaryCard(
          title: 'Take-off Summary',
          totalWeight: results['takeoffWeight'],
          cg: results['takeoffCg'],
          status: results['takeoffStatus'],
        ),
        pw.SizedBox(height: 10),
        _buildSummaryCard(
          title: 'Landing Summary',
          totalWeight: results['landingWeight'],
          cg: results['landingCg'],
          status: results['landingStatus'],
        ),
      ],
    );
  }

  pw.Widget _buildChartColumn(List<dynamic> envelope, Map<String, dynamic> results, pw.Font pwFont, PdfFont pdfFont, Uint8List chartImage) {
      final envelopePoints = envelope.map((p) => p as Map<String, dynamic>).toList();
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text('Center of Gravity Envelope', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Image(pw.MemoryImage(chartImage), fit: pw.BoxFit.contain),
          pw.SizedBox(height: 10),
          _buildLegend(pwFont, results),
        ],
      );
  }


  pw.Widget _buildSummaryCard({required String title, required double totalWeight, required double cg, required String status}) {
    final statusColor = status == 'Within Limits' ? PdfColors.green400 : PdfColors.red400;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        _buildTableRow('Total Weight:', '${totalWeight.toStringAsFixed(2)} kg', ''),
        _buildTableRow('Center of Gravity:', '${(cg / 1000).toStringAsFixed(3)} m', ''),
        pw.Row(
          children: [
            pw.Text('Status:', style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(width: 5),
            pw.Text(status, style: pw.TextStyle(color: statusColor, fontWeight: pw.FontWeight.bold, fontSize: 12)),
          ]
        ),
        pw.SizedBox(height: 10),
        pw.Divider(height: 1, color: PdfColors.grey300),
      ]
    );
  }

  pw.Widget _buildLoadStationsTable(Map<String, dynamic> data, Map<String, dynamic> results) {
    final aircraftType = data['aircraftType'] as String;

    Map<String, double> loadStations = {
      'Empty Weight': data['emptyWeight'],
      'Front Seats': results['frontSeatsWeight'],
      'Rear Seats': results['rearSeatsWeight'],
      if (aircraftType == 'DA42 VI') 'Nose Baggage': results['noseBaggageWeight'],
      'Baggage': results['baggageWeight'],
    };

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Load Stations', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Divider(height: 10, thickness: 1),
        ...loadStations.entries.map((e) => _buildTableRow(e.key, e.value.toStringAsFixed(2), 'kg')),
      ],
    );
  }

  pw.Widget _buildTableRow(String label, String value, String unit) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(width: 10),
          pw.Text(value, style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(width: 5),
          pw.Text(unit, style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  pw.Widget _buildLegend(pw.Font font, Map<String, dynamic> summary) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        _buildLegendItem(const PdfColor.fromInt(0xFF42A5F5), 'CG Envelope', font),
        pw.SizedBox(width: 24),
        _buildLegendItem(const PdfColor.fromInt(0xFF4CAF50), 'Takeoff Point', font),
        pw.SizedBox(width: 24),
        _buildLegendItem(const PdfColor.fromInt(0xFFF44336), 'Landing Point', font),
      ],
    );
  }

  pw.Widget _buildLegendItem(PdfColor color, String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.ClipOval(
            child: pw.Container(width: 12, height: 12, color: color),
          ),
          pw.SizedBox(width: 8),
          pw.Text(text, style: pw.TextStyle(font: font, fontSize: 10)),
        ],
      ),
    );
  }
}