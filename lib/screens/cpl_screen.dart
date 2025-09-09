import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/screens/qcm_category_screen.dart';
import 'package:brie_fly/screens/qr_screen.dart';
import 'package:brie_fly/services/ads/interstitial_ad_service.dart';

class CplScreen extends StatelessWidget {
  const CplScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundContainer(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1100;
              final tileWidth = isWide ? 360.0 : 300.0;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).maybePop(),
                          tooltip: 'Retour',
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'CPL',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 30,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Licence de Pilote Commercial',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.montserrat(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48), // balance back button width for perfect centering
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Wrap(
                          spacing: 28,
                          runSpacing: 28,
                          alignment: WrapAlignment.center,
                          children: [
                            SizedBox(
                              width: tileWidth,
                              height: 200,
                              child: _GlassNavTile(
                                icon: Icons.quiz_outlined,
                                title: 'QCMs',
                                subtitle: 'Entraînez-vous par catégories',
                                tooltip: 'Accéder aux QCM par matières et catégories',
                                accentColor: const Color(0xFF4DD0E1), // Cyan accent
                                onTap: () async {
                                  // Try to show an interstitial when entering QCMs
                                  await InterstitialAdService.loadIfNeeded();
                                  await InterstitialAdService.showIfAvailable();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const QcmCategoryScreen()),
                                  );
                                },
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              height: 200,
                              child: _GlassNavTile(
                                icon: Icons.question_answer_outlined,
                                title: 'Q/R',
                                subtitle: 'Questions & Réponses guidées',
                                tooltip: 'Révisions dirigées question par question',
                                accentColor: const Color(0xFFFFB74D), // Amber accent
                                onTap: () async {
                                  // Try to show an interstitial when entering Q/R
                                  await InterstitialAdService.loadIfNeeded();
                                  await InterstitialAdService.showIfAvailable();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const QrScreen()),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GlassNavTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? tooltip;
  final Color accentColor;
  final VoidCallback onTap;
  const _GlassNavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tooltip,
    this.accentColor = const Color(0xFF90CAF9),
  });

  @override
  State<_GlassNavTile> createState() => _GlassNavTileState();
}

class _GlassNavTileState extends State<_GlassNavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.identity()
          ..translate(0.0, _hovered ? -2.0 : 0.0)
          ..scale(_hovered ? 1.02 : 1.0),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.20),
                    Colors.white.withOpacity(0.07),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(_hovered ? 0.35 : 0.25),
                    blurRadius: _hovered ? 18 : 12,
                    offset: const Offset(0, 12),
                  )
                ],
              ),
              child: Container(
                // Gradient border effect
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: widget.accentColor.withOpacity(0.45), width: 1.2),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Tooltip(
                    message: widget.tooltip ?? widget.title,
                    waitDuration: const Duration(milliseconds: 500),
                    child: InkWell(
                      onTap: widget.onTap,
                      splashColor: widget.accentColor.withOpacity(0.25),
                      highlightColor: Colors.white.withOpacity(0.06),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        widget.accentColor.withOpacity(0.55),
                                        widget.accentColor.withOpacity(0.20),
                                      ],
                                    ),
                                    border: Border.all(color: Colors.white.withOpacity(0.35)),
                                  ),
                                  child: Icon(widget.icon, color: Colors.white, size: 28),
                                ),
                                const Spacer(),
                                Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  widget.subtitle,
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

