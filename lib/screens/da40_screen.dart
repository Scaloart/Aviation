import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/screens/da40/garmin_screen.dart';
import 'package:brie_fly/screens/da40/playlist_screen.dart';
import 'package:brie_fly/screens/da40/documents_screen.dart';

class Da40Screen extends StatefulWidget {
  const Da40Screen({super.key});

  @override
  State<Da40Screen> createState() => _Da40ScreenState();
}

class _Da40ScreenState extends State<Da40Screen> {
  String? _hoveredCard;

  @override
  Widget build(BuildContext context) {
    return BackgroundContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('DA40 NG', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCategoryCard(
                  context,
                  title: 'GARMIN',
                  description: 'Manuels et guides pour le G1000.',
                  icon: FontAwesomeIcons.folder,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GarminScreen())),
                ),
                const SizedBox(height: 24),
                _buildCategoryCard(
                  context,
                  title: 'Playlist',
                  description: 'Vidéos de formation et briefings.',
                  icon: FontAwesomeIcons.film,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PlaylistScreen())),
                ),
                const SizedBox(height: 24),
                _buildCategoryCard(
                  context,
                  title: 'Documents',
                  description: 'Documentation technique et manuels de vol.',
                  icon: FontAwesomeIcons.solidFileLines,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DocumentsScreen())),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, {required String title, required String description, required IconData icon, required VoidCallback onTap}) {
    final isHovered = _hoveredCard == title;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredCard = title),
      onExit: (_) => setState(() => _hoveredCard = null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(isHovered ? 0.3 : 0.2),
                Colors.white.withOpacity(isHovered ? 0.2 : 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(isHovered ? 0.5 : 0.3),
              width: 1.5,
            ),
            boxShadow: isHovered ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ] : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Row(
                children: [
                  FaIcon(icon, color: Colors.white, size: 36),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.8)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

