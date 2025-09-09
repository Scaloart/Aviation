import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:xml/xml.dart';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_combiner/pdf_combiner.dart' as pdf_combiner;
import 'package:pdf_combiner/responses/pdf_combiner_status.dart';
import 'package:brie_fly/models/notam_model.dart';
import 'package:brie_fly/models/temsi_chart_model.dart';
import 'package:brie_fly/models/wintem_chart_model.dart';
import 'package:brie_fly/models/temsi_chart_model.dart';

class PdfService {

  Future<Map<String, dynamic>> fetchOpmetsForDebug(List<String> airports) async {
    return await _fetchOpmets(airports);
  }
  final String _apiKey = '4ee9c75b70b54f24a56a22ea60be3aa9';

  Future<Map<String, dynamic>> _fetchOpmets(List<String> airports) async {
    final opmets = <String, Map<String, String>>{};
    final stationString = airports.join(',');

    try {
      final headers = {'X-API-Key': _apiKey};
      final errorMessages = <String>[];

      // Fetch METAR and TAF for each airport
      for (final airport in airports) {
        final metarUrl = 'https://api.checkwx.com/metar/$airport/decoded';
        final tafUrl = 'https://api.checkwx.com/taf/$airport/decoded';

        final responses = await Future.wait([
          http.get(Uri.parse(metarUrl), headers: headers).timeout(const Duration(seconds: 30)),
          http.get(Uri.parse(tafUrl), headers: headers).timeout(const Duration(seconds: 30)),
        ]);

        // Parse METAR
        if (responses[0].statusCode == 200) {
          final metarJson = json.decode(responses[0].body);
          if (metarJson['data'] != null && (metarJson['data'] as List).isNotEmpty) {
            opmets.putIfAbsent(airport, () => {})['METAR'] = metarJson['data'][0]['raw_text'];
          } else {
            // Log if data is empty
            print('METAR data for $airport is empty. Response: ${responses[0].body}');
          }
        } else { 
          errorMessages.add('METAR for $airport: ${responses[0].statusCode} ${responses[0].body}'); 
        }

        // Parse TAF
        if (responses[1].statusCode == 200) {
          final tafJson = json.decode(responses[1].body);
          if (tafJson['data'] != null && (tafJson['data'] as List).isNotEmpty) {
            opmets.putIfAbsent(airport, () => {})['TAF'] = tafJson['data'][0]['raw_text'];
          } else {
            // Log if data is empty
            print('TAF data for $airport is empty. Response: ${responses[1].body}');
          }
        } else { 
          errorMessages.add('TAF for $airport: ${responses[1].statusCode} ${responses[1].body}'); 
        }
      }

      return {'data': opmets, 'error': errorMessages.isNotEmpty ? errorMessages.join('\n') : null};
    } catch (e) {
      return {'data': opmets, 'error': e.toString()};
    }
  }


    Future<File> generateDossierPdf(
    String airportCodes, 
    List<SelectedTemsiChart> selectedTemsiCharts, 
    List<SelectedWintemChart> selectedWindCharts, 
    List<Notam> notams,
    Uint8List? navLogBytes,
    Uint8List? flightPlanBytes,
    Uint8List? balanceSheetBytes,
    String dossierNumber,
    String category,
    String productionDate,
    String qualityCode,
    String via,
    List<String> selectedItems,
    Map<String, dynamic> opmetResult // Accept pre-fetched data
  ) async {
    final pdf = pw.Document();
    // Track if any pages were added to the main document.
    bool pagesAdded = false;

    final font = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final backgroundImage = pw.MemoryImage((await rootBundle.load('assets/back.jpg')).buffer.asUint8List());
    final ttf = pw.Font.ttf(font);

    // OPMET Pages
    if (selectedItems.contains('METAR / TAF / SIGMET')) {
      final airports = airportCodes.split(',').where((s) => s.isNotEmpty).toList();
      // No longer need to fetch here, data is passed in
      final opmets = opmetResult['data'] as Map<String, Map<String, String>>;
      final opmetError = opmetResult['error'] as String?;

      if (opmetError != null) {
        pdf.addPage(_buildErrorPage(ttf, backgroundImage, opmetError));
        pagesAdded = true;
      } else {
        pdf.addPage(pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(0),
            buildBackground: (context) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Image(backgroundImage, fit: pw.BoxFit.fill),
            ),
          ),
          build: (context) => [
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(30, 120, 30, 30),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildDossierInfo(ttf, dossierNumber, via, category, productionDate),
                  pw.SizedBox(height: 20),
                  pw.Center(
                    child: pw.Container(
                      color: const PdfColor.fromInt(0xFFB3E5FC),
                      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      child: pw.Text('MESSAGES OPMETS', style: pw.TextStyle(font: ttf, fontSize: 12, color: PdfColors.black)),
                    ),
                  ),
                  ..._buildSectionWidgets(ttf, opmets, airports, 'METAR', 'Message METAR(+SPECI)'),
                  pw.SizedBox(height: 20),
                  ..._buildSectionWidgets(ttf, opmets, airports, 'TAF', 'Message TAF LONG'),
                ],
              ),
            ),
          ],
        ));
        pagesAdded = true;
      }
    }

    // TEMSI Charts
    if (selectedItems.contains('Carte TEMSI')) {
      if (selectedTemsiCharts.isEmpty) {
        pdf.addPage(pw.Page(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            buildBackground: (context) => pw.Image(backgroundImage, fit: pw.BoxFit.cover),
          ),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Text('No TEMSI charts selected.', style: pw.TextStyle(font: ttf)),
            );
          },
        ));
        pagesAdded = true;
      } else {
        final temsiImages = await Future.wait(selectedTemsiCharts.map((c) => _fetchImage(c.imageUrl)));
        for (var i = 0; i < selectedTemsiCharts.length; i++) {
          pdf.addPage(pw.Page(
            pageTheme: pw.PageTheme(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(0),
              buildBackground: (context) => pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(backgroundImage, fit: pw.BoxFit.fill),
              ),
            ),
            build: (pw.Context context) {
              return pw.Center(
                child: temsiImages[i] != null
                    ? pw.Image(pw.MemoryImage(temsiImages[i] as Uint8List), fit: pw.BoxFit.contain)
                    : pw.Text('Failed to load TEMSI image', style: pw.TextStyle(font: ttf, color: PdfColors.red)),
              );
            },
          ));
          pagesAdded = true;
        }
      }
    }

    // WINTEM Charts
    if (selectedItems.contains('Carte WINTEM')) {
      if (selectedWindCharts.isEmpty) {
        pdf.addPage(pw.Page(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            buildBackground: (context) => pw.Image(backgroundImage, fit: pw.BoxFit.cover),
          ),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Text('No WINTEM charts selected.', style: pw.TextStyle(font: ttf)),
            );
          },
        ));
        pagesAdded = true;
      } else {
        final wintemImages = await Future.wait(selectedWindCharts.map((c) => _fetchImage(c.imageUrl)));
        // We know we will add at least one page; mark content added.
        pagesAdded = true;
        for (var i = 0; i < selectedWindCharts.length; i++) {
          pdf.addPage(pw.Page(
            pageTheme: pw.PageTheme(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(0),
              buildBackground: (context) => pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(backgroundImage, fit: pw.BoxFit.fill),
              ),
            ),
            build: (pw.Context context) {
              return pw.Center(
                child: wintemImages[i] != null
                    ? pw.Image(pw.MemoryImage(wintemImages[i] as Uint8List), fit: pw.BoxFit.contain)
                    : pw.Text('Failed to load WINTEM image', style: pw.TextStyle(font: ttf, color: PdfColors.red)),
              );
            },
          ));
        }
      }
    }

    // NOTAMs Page
    if (selectedItems.contains('NOTAMs')) {
      final notamBackground = pw.MemoryImage((await rootBundle.load('assets/faaback.jpg')).buffer.asUint8List());
      if (notams.isEmpty) {
        pdf.addPage(pw.Page(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            buildBackground: (context) => pw.Image(backgroundImage, fit: pw.BoxFit.cover),
            margin: const pw.EdgeInsets.all(40),
          ),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Text('No NOTAMs available for the selected airports.', style: pw.TextStyle(font: ttf)),
            );
          },
        ));
        pagesAdded = true;
      } else {
        final now = DateTime.now().toUtc();
        final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
        pdf.addPage(pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            buildBackground: (context) => pw.Image(notamBackground, fit: pw.BoxFit.cover),
            margin: const pw.EdgeInsets.all(40),
          ),
          header: (pw.Context context) {
            return pw.SizedBox(height: 80);
          },
          footer: (pw.Context context) {
            final courier = pw.Font.courier();
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Divider(thickness: 1, color: PdfColors.black),
                pw.SizedBox(height: 5),
                pw.Text(
                  'PDF generated by Federal NOTAM Systems on: $formattedDate UTC',
                  style: pw.TextStyle(font: courier, color: PdfColors.black, fontSize: 10),
                ),
              ]
            );
          },
          build: (context) {
            final courier = pw.Font.courier();
            return [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: List<pw.Widget>.generate(notams.length, (int i) {
                  final notam = notams[i];
                  String formattedBody = notam.body.trim().replaceAllMapped(
                      RegExp(r' ([ABCDEFG])\)'), (match) => '\n${match.group(1)})');
                  return pw.Container(
                    width: 450,
                    margin: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(notam.title, style: pw.TextStyle(font: courier, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.left),
                        pw.SizedBox(height: 5),
                        pw.Text(formattedBody, style: pw.TextStyle(font: courier), textAlign: pw.TextAlign.left),
                        if (i < notams.length - 1) ...[
                          pw.SizedBox(height: 10),
                          pw.Divider(borderStyle: pw.BorderStyle.dotted),
                          pw.SizedBox(height: 10),
                        ],
                      ],
                    ),
                  );
                }),
              ),
            ];
          },
        ));
        // Mark that we added content when NOTAMs exist
        pagesAdded = true;
      }
    }


    // Save the main document only if it has pages
    Uint8List? mainPdfBytes;
    if (pagesAdded) {
      mainPdfBytes = await pdf.save();
    }

    // Create a list of PDF documents to merge
    final pdfsToMerge = <Uint8List>[];
    if (mainPdfBytes != null) {
      pdfsToMerge.add(mainPdfBytes);
    }

    // Add nav log if it exists
    if (selectedItems.contains('LOG de Navigation') && navLogBytes != null) {
      pdfsToMerge.add(navLogBytes);
    }

    // Add flight plan if it exists
    if (selectedItems.contains('Plan de Vol') && flightPlanBytes != null) {
      pdfsToMerge.add(flightPlanBytes);
    }

    // Add balance sheet if it exists
    if (selectedItems.contains('Masse et Centrage') && balanceSheetBytes != null) {
      pdfsToMerge.add(balanceSheetBytes);
    }

    // Merge all PDF documents (if more than one), otherwise use the single one
    final Uint8List mergedPdfBytes;
    if (pdfsToMerge.isEmpty) {
      // As a fallback, create a minimal stub page if nothing was selected (shouldn't happen in normal flow)
      final stub = pw.Document()
        ..addPage(pw.Page(build: (ctx) => pw.Center(child: pw.Text('Aucun contenu sélèctionné.'))));
      mergedPdfBytes = await stub.save();
    } else if (pdfsToMerge.length > 1) {
      mergedPdfBytes = await _mergePdfs(pdfsToMerge);
    } else {
      mergedPdfBytes = pdfsToMerge.first;
    }

    // Save the final merged document
    final directory = await getApplicationDocumentsDirectory();
    final dossierDir = Directory('${directory.path}/dossiers');
    if (!await dossierDir.exists()) {
      await dossierDir.create(recursive: true);
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'Dossier_${dossierNumber}_$timestamp.pdf';
    final file = File("${dossierDir.path}/$fileName");
    await file.writeAsBytes(mergedPdfBytes);

    return file;
  }

  Future<Uint8List> _fetchImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      // ignore: avoid_print
      print('Failed to fetch image: $e');
    }
    // Return a transparent 1x1 pixel image as a fallback
    return Uint8List.fromList([
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 96, 0, 0, 0, 2, 0, 1, 226, 33, 188, 51, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
    ]);
  }

  pw.Page _buildErrorPage(pw.Font ttf, pw.ImageProvider backgroundImage, String error) {
    return pw.Page(
      build: (context) => pw.Stack(
        children: [
          pw.Image(backgroundImage, fit: pw.BoxFit.cover),
          pw.Center(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(40),
              child: pw.Text('Failed to load OPMET data:\n$error', style: pw.TextStyle(font: ttf, fontSize: 12, color: PdfColors.red), textAlign: pw.TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildDossierInfo(pw.Font ttf, String dossierNumber, String via, String category, String productionDate) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.RichText(
              text: pw.TextSpan(
                style: pw.TextStyle(font: ttf, fontSize: 11, color: PdfColors.black),
                children: [
                  pw.TextSpan(text: 'Dossier de vol : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.TextSpan(text: '$dossierNumber via : ($via)'),
                ],
              ),
            ),
            pw.SizedBox(height: 5),
            pw.RichText(
              text: pw.TextSpan(
                style: pw.TextStyle(font: ttf, fontSize: 11, color: PdfColors.black),
                children: [
                  pw.TextSpan(text: 'Catégorie       : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.TextSpan(text: category),
                ],
              ),
            ),
            pw.SizedBox(height: 5),
            pw.RichText(
              text: pw.TextSpan(
                style: pw.TextStyle(font: ttf, fontSize: 11, color: PdfColors.black),
                children: [
                  pw.TextSpan(text: 'Date de production : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.TextSpan(text: productionDate),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<Uint8List> _mergePdfs(List<Uint8List> pdfs) async {
    final tempDir = await getTemporaryDirectory();
    final inputPaths = <String>[];

    try {
      for (int i = 0; i < pdfs.length; i++) {
        final path = '${tempDir.path}/input_$i.pdf';
        final file = File(path);
        await file.writeAsBytes(pdfs[i]);
        inputPaths.add(path);
      }

      final outputPath = '${tempDir.path}/merged_output.pdf';
      final response = await pdf_combiner.PdfCombiner.mergeMultiplePDFs(
        inputPaths: inputPaths,
        outputPath: outputPath,
      );

            if (response.status == PdfCombinerStatus.success) {
        final mergedFile = File(outputPath);
        final mergedBytes = await mergedFile.readAsBytes();
        await mergedFile.delete();
        return mergedBytes;
      } else {
        throw Exception('Failed to merge PDFs: ${response.message}');
      }
    } finally {
      for (final path in inputPaths) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
  }

  List<pw.Widget> _buildSectionWidgets(pw.Font ttf, Map<String, Map<String, String>> opmets, List<String> airports, String messageType, String title) {
    final sectionContent = <pw.Widget>[];

    for (final airport in airports) {
      if (opmets.containsKey(airport) && opmets[airport]!.containsKey(messageType) && opmets[airport]![messageType]!.isNotEmpty) {
        sectionContent.add(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(airport, style: pw.TextStyle(font: ttf, fontSize: 11, color: PdfColors.blue800, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text(opmets[airport]![messageType]!, style: pw.TextStyle(font: ttf, fontSize: 11), textAlign: pw.TextAlign.left),
              pw.SizedBox(height: 15),
            ],
          ),
        );
      }
    }

    if (sectionContent.isEmpty) {
      sectionContent.add(pw.Center(child: pw.Text('No $messageType data available for the selected airports.', style: pw.TextStyle(font: ttf, fontSize: 11, color: PdfColors.grey))));
    }

    return [
      pw.Text(title, style: pw.TextStyle(font: ttf, fontSize: 12, color: PdfColors.pink)),
      pw.Divider(thickness: 0.5, color: PdfColors.black),
      pw.SizedBox(height: 15),
      ...sectionContent,
    ];
  }
}

