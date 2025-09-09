import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:brie_fly/services/kmz_service.dart';

class KmzReaderScreen extends StatefulWidget {
  final String assetPath; // e.g., 'assets/NAV.kmz'
  const KmzReaderScreen({super.key, this.assetPath = 'assets/NAV.kmz'});

  @override
  State<KmzReaderScreen> createState() => _KmzReaderScreenState();
}

class _KmzReaderScreenState extends State<KmzReaderScreen> {
  late Future<KmlDocumentModel> _future;
  final _svc = KmzService();

  @override
  void initState() {
    super.initState();
    _future = _svc.loadFromAsset(widget.assetPath);
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('KMZ Reader', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: FutureBuilder<KmlDocumentModel>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Erreur de chargement: ${snapshot.error}',
                    style: GoogleFonts.montserrat(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final model = snapshot.data!;
            if (model.placemarks.isEmpty) {
              return Center(
                child: Text('Aucune entité trouvée dans le fichier KML.', style: GoogleFonts.montserrat(color: Colors.white70)),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: model.placemarks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final pm = model.placemarks[index];
                final icon = pm.type == 'Point'
                    ? Icons.place
                    : pm.type == 'LineString'
                        ? Icons.timeline
                        : Icons.polyline; // Polygon icon
                return Card(
                  color: Colors.white.withOpacity(0.12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(icon, color: Colors.white70),
                    title: Text(pm.name, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: Text('${pm.type} • ${pm.points.length} points', style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 13)),
                    onTap: () {
                      _showPlacemarkDetails(pm);
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showPlacemarkDetails(KmlPlacemark pm) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(pm.name, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Text(
                _formatCoords(pm),
                style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Fermer', style: GoogleFonts.montserrat(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  String _formatCoords(KmlPlacemark pm) {
    final buf = StringBuffer('Type: ${pm.type}\n\n');
    for (var i = 0; i < pm.points.length; i++) {
      final p = pm.points[i];
      buf.writeln('#${i + 1}: lat=${p.lat.toStringAsFixed(6)}, lon=${p.lon.toStringAsFixed(6)}');
    }
    return buf.toString();
  }
}

