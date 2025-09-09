import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/screens/aerodromes_screen.dart';
import 'package:brie_fly/screens/arretes_list_screen.dart';
import 'package:brie_fly/screens/annexes_oaci_list_screen.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  String? _hoveredCard;

  @override
  Widget build(BuildContext context) {
    return BackgroundContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Documents', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
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
                _buildDocumentCategoryCard(
                  context,
                  title: 'ARRETES',
                  description: 'Consultez les derniers arrêtés et réglementations en vigueur.',
                  icon: FontAwesomeIcons.gavel,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ArretesListScreen())),
                ),
                const SizedBox(height: 24),
                _buildDocumentCategoryCard(
                  context,
                  title: 'ANNEXES OACI',
                  description: 'Explorez les annexes de l\'OACI, standards internationaux de l\'aviation.',
                  icon: FontAwesomeIcons.bookAtlas,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AnnexesOaciListScreen())),
                ),
                const SizedBox(height: 24),
                _buildDocumentCategoryCard(
                  context,
                  title: 'AERODROMES',
                  description: 'Fiches et informations sur les aérodromes marocains.',
                  icon: FontAwesomeIcons.planeDeparture,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AerodromesScreen())),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentCategoryCard(BuildContext context, {required String title, required String description, required IconData icon, required VoidCallback onTap}) {
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

