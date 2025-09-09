import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:brie_fly/screens/cpl_screen.dart';
import 'package:brie_fly/screens/ir_screen.dart';
import 'package:brie_fly/screens/documents_screen.dart';
import 'package:brie_fly/screens/resumes_screen.dart';
import 'package:brie_fly/screens/english_l4_screen.dart';
import 'package:provider/provider.dart';
import 'package:brie_fly/services/auth_service.dart';
import 'package:brie_fly/screens/aircraft_selection_screen.dart';
import 'package:brie_fly/screens/account_screen.dart';
import 'package:brie_fly/screens/profile_screen.dart';
import 'package:brie_fly/screens/briefing_screen.dart';
import 'package:brie_fly/screens/da40_screen.dart';
import 'package:brie_fly/screens/da42/da42_screen.dart';
import 'package:brie_fly/screens/subscription_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:brie_fly/models/app_user.dart';
import 'package:brie_fly/models/dossier_info.dart';
// Removed Salah Video imports

class HomeScreen extends StatefulWidget {
  final AppUser user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  String? _hoveredButtonLabel;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final bool isSubscribed = widget.user.isSubscribed;
    final bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (isDesktop && constraints.maxWidth > 800) {
          return _buildDesktopLayout(context, authService, isSubscribed);
        } else {
          return _buildMobileLayout(context, authService, isSubscribed);
        }
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context, AuthService authService, bool isSubscribed) {
    return BackgroundContainer(
      padding: EdgeInsets.zero,
      padForBanner: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Main content
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AutoSizeText(
                              'BrieFly',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  const Shadow(blurRadius: 10.0, color: Colors.black, offset: Offset(2.0, 2.0)),
                                ],
                              ),
                              maxLines: 2,
                              minFontSize: 20,
                              stepGranularity: 1,
                            ),
                            const SizedBox(height: 10),
                            const AutoSizeText(
                              'All You Need To Fly 😉',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Columbia',
                                fontSize: 18.0,
                                fontWeight: FontWeight.normal,
                                color: Colors.white70,
                              ),
                              maxLines: 1,
                            ),
                            const SizedBox(height: 40),
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                              childAspectRatio: 1.2,
                              children: [
                                _buildGlassMorphismButton(
                                  context,
                                  label: 'CPL',
                                  icon: FontAwesomeIcons.fileSignature,
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CplScreen())),
                                  isLocked: !isSubscribed,
                                ),
                                _buildGlassMorphismButton(
                                  context,
                                  label: 'IR',
                                  icon: FontAwesomeIcons.gaugeHigh,
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const IrScreen())),
                                  isLocked: !isSubscribed,
                                ),
                                _buildGlassMorphismButton(
                                  context,
                                  label: 'Documents',
                                  icon: FontAwesomeIcons.fileContract,
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DocumentsScreen())),
                                  isLocked: !isSubscribed,
                                ),
                                _buildGlassMorphismButton(
                                  context,
                                  label: 'Resumes',
                                  icon: FontAwesomeIcons.solidFileLines,
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ResumesScreen())),
                                  isLocked: !isSubscribed,
                                ),
                                _buildGlassMorphismButton(
                                  context,
                                  label: 'DA40 NG',
                                  icon: FontAwesomeIcons.plane,
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Da40Screen())),
                                  isLocked: !isSubscribed,
                                ),
                                _buildGlassMorphismButton(
                                  context,
                                  label: 'DA42 VI',
                                  icon: FontAwesomeIcons.planeUp,
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DA42Screen())),
                                  isLocked: !isSubscribed,
                                ),
                                _buildGlassMorphismButton(
                                  context,
                                  label: 'ENGLISH L4',
                                  icon: FontAwesomeIcons.language,
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EnglishL4Screen())),
                                  isLocked: !isSubscribed,
                                ),
                                _buildGlassMorphismButton(
                                  context,
                                  label: 'DOSSIER DE VOL',
                                  icon: FontAwesomeIcons.fileAlt,
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => BriefingScreen(user: widget.user))),
                                  isLocked: !isSubscribed,
                                ),
                                _buildGlassMorphismButton(
                                  context,
                                  label: 'MON COMPTE',
                                  icon: FontAwesomeIcons.userCircle,
                                  onPressed: () {
                                    if (authService.currentUser != null) {
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(user: widget.user)));
                                    } else {
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountScreen()));
                                    }
                                  },
                                ),
                                _buildGlassMorphismButton(
                                  context,
                                  label: 'QUITTER',
                                  icon: FontAwesomeIcons.powerOff,
                                  onPressed: () {
                                    if (Platform.isAndroid) {
                                      SystemNavigator.pop();
                                    } else {
                                      exit(0);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Footer as normal bottom content (scrolls when content long)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20.0, top: 16.0),
                          child: _buildSignature(),
                        ),
                        const SizedBox(height: 16), // small gap above global banner
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, AuthService authService, bool isSubscribed) {
    return BackgroundContainer(
      padForBanner: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              _buildAppTitle(isDesktop: true),
              const Spacer(flex: 3),
              _buildDesktopNavBar(context, authService, isSubscribed),
              const Spacer(flex: 1),
              _buildSignature(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopNavBar(BuildContext context, AuthService authService, bool isSubscribed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildDesktopNavButton(context, 'CPL', FontAwesomeIcons.fileSignature, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CplScreen())), isLocked: !isSubscribed),
          const SizedBox(width: 40),
          _buildDesktopNavButton(context, 'IR', FontAwesomeIcons.gaugeHigh, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const IrScreen())), isLocked: !isSubscribed),
          const SizedBox(width: 40),
          _buildDesktopNavButton(context, 'DOCUMENTS', FontAwesomeIcons.fileContract, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DocumentsScreen())), isLocked: !isSubscribed),
          const SizedBox(width: 40),
          _buildDesktopNavButton(context, 'RESUMES', FontAwesomeIcons.solidFileLines, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ResumesScreen())), isLocked: !isSubscribed),
          const SizedBox(width: 40),
          _buildDesktopNavButton(context, 'DA40 NG', FontAwesomeIcons.plane, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Da40Screen())), isLocked: !isSubscribed),
          const SizedBox(width: 40),
          _buildDesktopNavButton(context, 'DA42 VI', FontAwesomeIcons.planeUp, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DA42Screen())), isLocked: !isSubscribed),
          const SizedBox(width: 40),
          _buildDesktopNavButton(context, 'ENGLISH L4', FontAwesomeIcons.language, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EnglishL4Screen())), isLocked: !isSubscribed),
          const SizedBox(width: 40),
          _buildDesktopNavButton(
            context,
            'DOSSIER DE VOL',
            FontAwesomeIcons.fileAlt,
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => BriefingScreen(user: widget.user))),
            isLocked: !isSubscribed,
          ),
          const SizedBox(width: 20),
          _buildDesktopNavButton(
            context,
            'MON COMPTE',
            FontAwesomeIcons.userCircle,
            () {
              if (authService.currentUser != null) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(user: widget.user)));
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountScreen()));
              }
            }
          ),
          const SizedBox(width: 20),
          _buildDesktopNavButton(
            context,
            'QUITTER',
            FontAwesomeIcons.powerOff,
            () {
              exit(0);
            }
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopNavButton(BuildContext context, String label, IconData icon, VoidCallback onPressed, {bool isLocked = false}) {
    final isHovered = _hoveredButtonLabel == label;
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredButtonLabel = label),
      onExit: (_) => setState(() => _hoveredButtonLabel = null),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: isHovered ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(icon, color: isLocked ? Colors.grey : Colors.white, size: 28),
                  onPressed: () async {
                    if (isLocked) {
                      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) {
                            final height = MediaQuery.of(ctx).size.height * 0.9;
                            return Container(
                              height: height,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.85),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              child: const SubscriptionScreen(),
                            );
                          },
                        );
                      } else {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                      }
                    } else {
                      onPressed();
                    }
                  },
                  splashRadius: 28,
                  hoverColor: Colors.white.withOpacity(0.1),
                ),
                if (isLocked)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(Icons.lock, color: Colors.amber, size: 16),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.montserrat(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppTitle({required bool isDesktop}) {
    final titleSize = isDesktop ? 64.0 : 48.0;
    final subtitleSize = isDesktop ? 24.0 : 18.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AutoSizeText(
          'BrieFly',
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: titleSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Colors.black.withOpacity(0.5),
                offset: const Offset(2.0, 2.0),
              ),
            ],
          ),
          maxLines: 1,
        ),
        const SizedBox(height: 16),
        AutoSizeText(
          'All You Need To Fly 😉',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Columbia',
            fontSize: subtitleSize,
            fontWeight: FontWeight.normal,
            color: Colors.white70,
          ),
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _buildGlassMorphismButton(BuildContext context, {required String label, required IconData icon, required VoidCallback onPressed, bool isLocked = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                if (isLocked) {
                  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) {
                        final height = MediaQuery.of(ctx).size.height * 0.9;
                        return Container(
                          height: height,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.85),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: const SubscriptionScreen(),
                        );
                      },
                    );
                  } else {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                  }
                } else {
                  onPressed();
                }
              },
              borderRadius: BorderRadius.circular(20),
              splashColor: Colors.white.withOpacity(0.3),
              highlightColor: Colors.white.withOpacity(0.1),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: isLocked ? Colors.grey : Colors.white, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          color: isLocked ? Colors.grey : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (isLocked)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  if (isLocked)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(Icons.lock, color: Colors.amber, size: 24),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignature() {
    return InkWell(
      onTap: () async {
        final Uri url = Uri.parse('https://www.instagram.com/nassihsalah');
        if (!await launchUrl(url)) {
          // Could show a snackbar or toast here
          // For now, just print to console
          debugPrint('Could not launch $url');
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          'NASSIH | EPL 03',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.7),
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class DesktopBackgroundContainer extends StatelessWidget {
  final Widget child;

  const DesktopBackgroundContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final List<String> images = [
      'assets/background_desktop.jpg',
      'assets/background.jpg',
      'assets/background2.jpg',
      'assets/background3.jpg',
      'assets/background4.jpg',
      'assets/mainback.png',
    ];

    return Stack(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: MediaQuery.of(context).size.height,
            viewportFraction: 1.0,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 5),
            enlargeCenterPage: false,
            pauseAutoPlayOnTouch: false,
            scrollPhysics: const NeverScrollableScrollPhysics(),
            autoPlayCurve: Curves.easeInCubic,
          ),
          items: images.map((item) => Image.asset(
            item,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          )).toList(),
        ),
        Container(
          color: Colors.black.withOpacity(0.4),
        ),
        child,
      ],
    );
  }
}

