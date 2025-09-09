import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/fpl_data.dart';

class FplPdfGenerator {
  static Future<String?> create(FplData fplData) async {
    try {
      // 1. Load assets
      final pdfData = await rootBundle.load('assets/pdf/7233-4.pdf');
      final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final ttf = pw.Font.ttf(fontData);
      final textStyle = pw.TextStyle(font: ttf, fontSize: 10);
      final smallTextStyle = pw.TextStyle(font: ttf, fontSize: 9);

      final uint8list = pdfData.buffer.asUint8List();

      // 2. Rasterize the second page of the PDF to an image
      final raster = await Printing.raster(
        uint8list,
        pages: [1], // 0-based index, so 1 is the second page
        dpi: 300, // Use a high DPI for good quality
      ).first;

      final formImage = pw.MemoryImage(await raster.toPng());

      // 3. Create a new PDF document
      final pdf = pw.Document();

      // 4. Add a page and use the rendered form image as the background
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(raster.width.toDouble(), raster.height.toDouble()),
          margin: const pw.EdgeInsets.all(0),
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                pw.Image(formImage, fit: pw.BoxFit.fill),

                // 5. Add text fields with the embedded font

                // Box 1. TYPE
                pw.Positioned(left: 145, top: 98, child: pw.Text(fplData.typeOfFlight ?? '', style: textStyle)),

                // Box 2. AIRCRAFT IDENTIFICATION
                pw.Positioned(left: 115, top: 135, child: pw.Text(fplData.aircraftId ?? '', style: textStyle)),

                // Box 3. AIRCRAFT TYPE/SPECIAL EQUIPMENT
                pw.Positioned(left: 360, top: 135, child: pw.Text('${fplData.aircraftType ?? ''}/${fplData.equipment ?? ''}', style: textStyle)),

                // Box 4. TRUE AIRSPEED
                pw.Positioned(left: 115, top: 180, child: pw.Text(fplData.cruisingSpeed ?? '', style: textStyle)),

                // Box 5. DEPARTURE POINT
                pw.Positioned(left: 230, top: 180, child: pw.Text(fplData.departureAerodrome ?? '', style: textStyle)),

                // Box 6. DEPARTURE TIME
                pw.Positioned(left: 420, top: 180, child: pw.Text(fplData.departureTime ?? '', style: textStyle)),

                // Box 7. CRUISING ALTITUDE
                pw.Positioned(left: 115, top: 225, child: pw.Text(fplData.flightLevel ?? '', style: textStyle)),

                // Box 8. ROUTE OF FLIGHT
                pw.Positioned(left: 50, top: 285, child: pw.Text(fplData.route ?? '', style: smallTextStyle)),

                // Box 9. DESTINATION
                pw.Positioned(left: 115, top: 358, child: pw.Text(fplData.destinationAerodrome ?? '', style: textStyle)),

                // Box 10. EST. TIME ENROUTE
                pw.Positioned(left: 420, top: 358, child: pw.Text(fplData.totalEet ?? '', style: textStyle)),

                // Box 11. REMARKS
                pw.Positioned(left: 50, top: 415, child: pw.Text(fplData.otherInfo['RMK'] ?? '', style: smallTextStyle)),

                // Box 12. FUEL ON BOARD
                pw.Positioned(left: 115, top: 468, child: pw.Text(fplData.otherInfo['FOB'] ?? '', style: textStyle)),

                // Box 13. ALTERNATE AIRPORT(S)
                pw.Positioned(left: 290, top: 468, child: pw.Text(fplData.altnAerodrome ?? '', style: textStyle)),

                // Box 14. PILOT'S NAME, ADDRESS & TEL #
                pw.Positioned(left: 50, top: 525, child: pw.Text(fplData.otherInfo['PILOT'] ?? '', style: smallTextStyle)),

                // Box 15. NUMBER ABOARD
                pw.Positioned(left: 420, top: 523, child: pw.Text(fplData.otherInfo['PAX'] ?? '', style: textStyle)),

                // Box 16. COLOR OF AIRCRAFT
                pw.Positioned(left: 50, top: 578, child: pw.Text(fplData.otherInfo['COLOR'] ?? '', style: textStyle)),
              ],
            );
          },
        ),
      );

      // 6. Save the document to a temporary file
      final outputDir = await getTemporaryDirectory();
      final outputFile = File('${outputDir.path}/faa_7233-4_filled.pdf');
      await outputFile.writeAsBytes(await pdf.save());

      return outputFile.path;
    } catch (e) {
      print('Error generating PDF: $e');
      return null;
    }
  }
}

