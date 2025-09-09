import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/models/app_user.dart';
import 'package:brie_fly/models/dossier_info.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:brie_fly/screens/dossiers_screen.dart';
import 'package:brie_fly/models/airport_model.dart';
import 'package:brie_fly/services/database_service.dart';
import 'package:brie_fly/services/navigation_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:brie_fly/services/ads/interstitial_ad_service.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

class BriefingScreen extends StatefulWidget {
  final AppUser user;
  final DossierInfo? dossierInfo;
  const BriefingScreen({super.key, required this.user, this.dossierInfo});

  @override
  _BriefingScreenState createState() => _BriefingScreenState();
}

class _BriefingScreenState extends State<BriefingScreen> {
  final DatabaseService _dbService = DatabaseService();

  // State for selected airports
  final List<Airport> _departAirports = [];
  final List<Airport> _arriveeAirports = [];
  final List<Airport> _enRouteAirports = [];

  // Controllers are used by the Autocomplete's text field
  final TextEditingController _departController = TextEditingController();
  final TextEditingController _arriveeController = TextEditingController();
  final TextEditingController _enRouteController = TextEditingController();

  final Map<String, bool> _selections = {
    'METAR / TAF / SIGMET': true,
    'Carte TEMSI': true,
    'Carte WINTEM': true,
    'NOTAMs': true,
    'LOG de Navigation': true,
    'Plan de Vol': true,
    'Masse et Centrage': true,
  };

  @override
  void initState() {
    super.initState();
    if (widget.dossierInfo != null) {
      _prefillData(widget.dossierInfo!); 
    }
  }

  Future<void> _prefillData(DossierInfo dossier) async {
    // Prefill airports
    _departAirports.addAll(await _getAirportsFromCodes(dossier.departAirportCodes));
    _arriveeAirports.addAll(await _getAirportsFromCodes(dossier.arriveeAirportCodes));
    _enRouteAirports.addAll(await _getAirportsFromCodes(dossier.enRouteAirportCodes));

    // Prefill selections
    for (var key in _selections.keys) {
      _selections[key] = dossier.selectedOptions.contains(key);
    }

    setState(() {});
  }

  Future<List<Airport>> _getAirportsFromCodes(List<String> codes) async {
    final List<Airport> airports = [];
    for (String code in codes) {
      final result = await _dbService.searchAirports(code);
      if (result.isNotEmpty && result.first.icaoCode == code) {
        airports.add(result.first);
      }
    }
    return airports;
  }

  @override
  void dispose() {
    _departController.dispose();
    _arriveeController.dispose();
    _enRouteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundContainer(
      padForBanner: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          'DOSSIER DE VOL',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                      // Removed Google Earth navigation button
                    ],
                  ),
                  const SizedBox(height: 30),
                  _buildAirportInputFields(),
                  const SizedBox(height: 30),
                  _buildGenerateButton(),
                  const SizedBox(height: 20),
                  _buildDossiersButton(),
                  const SizedBox(height: 30),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'OPTIONS DU DOSSIER',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSelectionContainer(),
                  const SizedBox(height: 40),
                  _buildSignature(),
                  const SizedBox(height: 16), // small gap above global banner
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAirportInputFields() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildSingleAirportInputField(
                label: 'DÉPART',
                hint: 'OACI de départ',
                controller: _departController,
                selectedAirports: _departAirports,
                allowMultiple: false,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 28.0), // Aligns the button with the text fields
              child: IconButton(
                icon: Icon(Icons.swap_horiz, color: Colors.white.withOpacity(0.7), size: 28),
                onPressed: () {
                  setState(() {
                    // Swap the airports
                    final temp = List<Airport>.from(_departAirports);
                    _departAirports.clear();
                    _departAirports.addAll(_arriveeAirports);
                    _arriveeAirports.clear();
                    _arriveeAirports.addAll(temp);
                  });
                },
              ),
            ),
            Expanded(
              child: _buildSingleAirportInputField(
                label: 'ARRIVÉE',
                hint: 'OACI d\'arrivée',
                controller: _arriveeController,
                selectedAirports: _arriveeAirports,
                allowMultiple: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSingleAirportInputField(
          label: 'AÉRODROME(S) EN ROUTE',
          hint: 'Entrez les OACI en route',
          controller: _enRouteController,
          selectedAirports: _enRouteAirports,
          allowMultiple: true,
        ),
      ],
    );
  }

  Widget _buildSingleAirportInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required List<Airport> selectedAirports,
    required bool allowMultiple,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        TypeAheadField<Airport>(
          suggestionsCallback: (pattern) async {
            if (pattern.trim().length < 2) return [];
            final results = await _dbService.searchAirports(pattern.trim());
            final allSelectedCodes = {
              ..._departAirports.map((a) => a.icaoCode),
              ..._arriveeAirports.map((a) => a.icaoCode),
              ..._enRouteAirports.map((a) => a.icaoCode),
            };
            return results.where((a) => !allSelectedCodes.contains(a.icaoCode)).toList(growable: false);
          },
          builder: (context, controllerFromBuilder, focusNode) {
            controller = controllerFromBuilder;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              style: GoogleFonts.montserrat(color: Colors.white),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.montserrat(color: Colors.white.withOpacity(0.5)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                prefixIcon: Icon(Icons.flight_takeoff, color: Colors.white.withOpacity(0.7)),
              ),
            );
          },
          itemBuilder: (context, Airport option) {
            return ListTile(
              leading: Icon(Icons.local_airport, color: Colors.white.withOpacity(0.7)),
              title: Text(option.name, style: GoogleFonts.montserrat(fontWeight: FontWeight.w500, color: Colors.white)),
              subtitle: Text(option.icaoCode, style: GoogleFonts.montserrat(color: Colors.white70)),
            );
          },
          onSelected: (Airport selection) {
            setState(() {
              if (!selectedAirports.any((a) => a.icaoCode == selection.icaoCode)) {
                if (allowMultiple) {
                  selectedAirports.add(selection);
                } else {
                  selectedAirports
                    ..clear()
                    ..add(selection);
                }
              }
            });
            controller.clear();
          },
          hideOnEmpty: true,
          emptyBuilder: (context) => const SizedBox.shrink(),
          decorationBuilder: (context, child) {
            return Material(
              elevation: 4.0,
              color: const Color(0xFF1A2A3A).withOpacity(0.95),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: child,
              ),
            );
          },
        ),
        if (selectedAirports.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: selectedAirports.map((airport) {
                return Chip(
                  label: Text(airport.icaoCode),
                  onDeleted: () {
                    setState(() {
                      selectedAirports.remove(airport);
                    });
                  },
                  backgroundColor: const Color(0xFF1E2B47),
                  labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, shadows: [Shadow(blurRadius: 1.0, color: Colors.black54)]),
                  deleteIconColor: Colors.white70,
                  shape: const StadiumBorder(), // Remove side border, use decoration
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  labelPadding: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                );
              }).toList().cast<Widget>(),
            ),
          ),
      ],
    );
  }

  Widget _buildDossiersButton() {
    return SizedBox(
      width: double.infinity, // Make button take full width
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DossiersScreen()),
          );
        },
        icon: const Icon(Icons.folder_open, color: Colors.white, size: 24),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'Dossiers Générés',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.5), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity, // Make button take full width
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF1976D2), Color(0xFF2196F3)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: () async {
            final selectedItems = _selections.entries
                .where((entry) => entry.value)
                .map((entry) => entry.key)
                .toList();

            if (selectedItems.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Veuillez sélectionner au moins un élément pour générer le dossier.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
              return;
            }

            // Combine airports from the state lists
            final departCodes = _departAirports.map((a) => a.icaoCode).join(',');
            final arriveeCodes = _arriveeAirports.map((a) => a.icaoCode).join(',');
            final enRouteCodes = _enRouteAirports.map((a) => a.icaoCode).join(',');

            final allCodes = [departCodes, arriveeCodes, enRouteCodes]
                .where((s) => s.isNotEmpty)
                .join(',');

            // Only require an airport if METAR/TAF/SIGMET is selected
            if ((_selections['METAR / TAF / SIGMET'] ?? false) && allCodes.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Veuillez entrer au moins un aéroport pour METAR/TAF/SIGMET.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
              return;
            }

            final route = NavigationService.getFirstScreenRoute(
              context: context,
              selectedItems: selectedItems,
              airportCodes: allCodes,
            );

            if (route != null) {
              await InterstitialAdService.loadIfNeeded();
              await InterstitialAdService.showIfAvailable();
              Navigator.push(context, route);
            }
          },
          icon: const Icon(Icons.airplanemode_active,
              color: Colors.white, size: 28),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              'Générer Dossier De VOL',
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionContainer() {
    final Map<String, IconData> _icons = {
      'METAR / TAF / SIGMET': FontAwesomeIcons.cloudSunRain,
      'Carte TEMSI': FontAwesomeIcons.mapLocationDot,
      'Carte WINTEM': FontAwesomeIcons.wind,
      'NOTAMs': FontAwesomeIcons.triangleExclamation,
      'LOG de Navigation': FontAwesomeIcons.solidFileLines,
      'Plan de Vol': FontAwesomeIcons.fileInvoice,
      'Masse et Centrage': FontAwesomeIcons.scaleBalanced,
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: _selections.keys.map((String key) {
          return SwitchListTile(
            secondary: Icon(_icons[key], color: Colors.white, size: 20),
            title: Text(key, style: GoogleFonts.montserrat(fontWeight: FontWeight.w500, color: Colors.white)),
            value: _selections[key]!,
            onChanged: (bool value) {
              setState(() {
                _selections[key] = value;
              });
            },
            activeColor: const Color(0xFF2196F3), // Match the button gradient
            inactiveTrackColor: Colors.white.withOpacity(0.2),
            inactiveThumbColor: Colors.white.withOpacity(0.5),
          );
        }).toList(),
      ),
    );
  }


  Widget _buildSignature() {
    return InkWell(
      onTap: () async {
        final Uri url = Uri.parse('https://www.instagram.com/nassihsalah');
        if (!await launchUrl(url)) {
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
            color: Colors.white70,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

