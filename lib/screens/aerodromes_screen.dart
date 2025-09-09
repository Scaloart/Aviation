import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/models/aerodrome.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:brie_fly/data/aerodrome_data.dart';
import 'package:brie_fly/screens/aerodrome_charts_screen.dart';

class AerodromesScreen extends StatefulWidget {
  const AerodromesScreen({super.key});

  @override
  State<AerodromesScreen> createState() => _AerodromesScreenState();
}

class _AerodromesScreenState extends State<AerodromesScreen> {
  int? _hoveredIndex;
  final _searchController = TextEditingController();
  List<Aerodrome> _filteredAerodromes = [];

  @override
  void initState() {
    super.initState();
    _filteredAerodromes = aerodromes;
    _searchController.addListener(_filterAerodromes);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterAerodromes);
    _searchController.dispose();
    super.dispose();
  }

  void _filterAerodromes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredAerodromes = aerodromes.where((aerodrome) {
        final nameMatches = aerodrome.name.toLowerCase().contains(query);
        final codeMatches = aerodrome.oaciCode.toLowerCase().contains(query);
        return nameMatches || codeMatches;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Aérodromes', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.montserrat(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Rechercher par nom ou code OACI...',
                  hintStyle: GoogleFonts.montserrat(color: Colors.white70),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _filteredAerodromes.length,
                itemBuilder: (context, index) {
                  final aerodrome = _filteredAerodromes[index];
                  final isHovered = _hoveredIndex == index;
                  return MouseRegion(
                    onEnter: (_) => setState(() => _hoveredIndex = index),
                    onExit: (_) => setState(() => _hoveredIndex = null),
                    cursor: SystemMouseCursors.click,
                    child: AnimatedScale(
                      scale: isHovered ? 1.03 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Card(
                        color: Colors.white.withOpacity(0.15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          title: Text(aerodrome.name, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600)),
                          subtitle: Text(aerodrome.oaciCode, style: GoogleFonts.montserrat(color: Colors.white70)),
                          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AerodromeChartsScreen(aerodrome: aerodrome),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


