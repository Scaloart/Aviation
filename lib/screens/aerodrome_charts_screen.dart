import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:brie_fly/models/aerodrome.dart';
import 'package:brie_fly/screens/pdf_viewer_screen.dart';
import 'package:brie_fly/widgets/background_container.dart';

class AerodromeChartsScreen extends StatefulWidget {
  final Aerodrome aerodrome;

  const AerodromeChartsScreen({Key? key, required this.aerodrome}) : super(key: key);

  @override
  State<AerodromeChartsScreen> createState() => _AerodromeChartsScreenState();
}

class _AerodromeChartsScreenState extends State<AerodromeChartsScreen> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    return BackgroundContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(widget.aerodrome.name, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: widget.aerodrome.charts.isEmpty
                ? Center(
                    child: Text(
                      'No charts available for this aerodrome.',
                      style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: widget.aerodrome.charts.length,
                    itemBuilder: (context, index) {
                      final chartGroup = widget.aerodrome.charts[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chartGroup.name,
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ..._buildChartList(chartGroup.pdfPaths, index),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChartList(List<String> pdfPaths, int groupIndex) {
    return pdfPaths.asMap().entries.map((entry) {
      int itemIndex = entry.key;
      String pdfPath = entry.value;
      final url = pdfPath;
      final title = pdfPath.split('/').last.replaceAll('_', ' ').replaceAll('.pdf', '');
      final uniqueIndex = groupIndex * 1000 + itemIndex; // Create a unique index for hover state
      final isHovered = _hoveredIndex == uniqueIndex;

      return MouseRegion(
        onEnter: (_) => setState(() => _hoveredIndex = uniqueIndex),
        onExit: (_) => setState(() => _hoveredIndex = null),
        cursor: SystemMouseCursors.click,
        child: AnimatedScale(
          scale: isHovered ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Card(
            color: Colors.white.withOpacity(0.15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: const Icon(Icons.picture_as_pdf, color: Colors.white70),
              title: Text(title, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w500)),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
              onTap: () async {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PdfViewerScreen(
                      url: url,
                      title: title,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }).toList();
  }
}

