import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:brie_fly/models/notam_model.dart';
import 'package:brie_fly/models/temsi_chart_model.dart';
import 'package:brie_fly/models/wintem_chart_model.dart';
import 'package:brie_fly/services/balance_sheet_pdf_service.dart';
import 'package:brie_fly/services/navigation_service.dart';
import 'package:brie_fly/balance_sheet_viewer_screen.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:brie_fly/widgets/app_window_bar.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';

// Data model for a single aircraft
class _Aircraft {
  final String registration;
  final double emptyWeight; // kg
  final double emptyCg;     // mm

  const _Aircraft({
    required this.registration,
    required this.emptyWeight,
    required this.emptyCg,
  });

  // Calculated property for empty moment
  double get emptyMoment => emptyWeight * emptyCg;
}

class WeightBalanceScreen extends StatefulWidget {
  final List<String> selectedItems;
  final String airportCodes;
  final List<SelectedTemsiChart> selectedTemsiCharts;
  final List<SelectedWintemChart> selectedWintemCharts;
  final List<Notam> notams;
  final String? navLogPath;
  final Uint8List? navLogBytes;
  final String flightPlanPath;
  final Uint8List? flightPlanBytes;
  final Uint8List? balanceSheetBytes;

  const WeightBalanceScreen({
    Key? key,
    required this.selectedItems,
    required this.airportCodes,
    this.navLogPath,
    this.navLogBytes,
    required this.flightPlanPath,
    this.flightPlanBytes,
    this.balanceSheetBytes,
    this.selectedTemsiCharts = const [],
    this.selectedWintemCharts = const [],
    this.notams = const [],
  }) : super(key: key);

  @override
  _WeightBalanceScreenState createState() => _WeightBalanceScreenState();
}

class _WeightBalanceScreenState extends State<WeightBalanceScreen> with TickerProviderStateMixin {
  final GlobalKey _chartRepaintKeyDa40 = GlobalKey();
  final GlobalKey _chartRepaintKeyDa42 = GlobalKey();
  final BalanceSheetPdfService _balanceSheetPdfService = BalanceSheetPdfService();
  late TabController _tabController;
  int _chartVersion = 0; // Bumped to force chart rebuilds

  // --- Chart Style Palette ---
  final Color _chartPrimaryColor = const Color(0xFF0D47A1); // Deep Blue
  final Color _chartEnvelopeColor = const Color(0xFF42A5F5); // Bright Blue
  final Color _chartTakeoffColor = const Color(0xFF4CAF50); // Green
  final Color _chartLandingColor = const Color(0xFFF44336); // Red
  final Color _chartGridColor = const Color(0xFFBDBDBD); // Grey
  final Color _chartEnvelopeBorderColor = const Color(0xFF1E88E5); // Darker Blue for border
  final Color _chartTextColor = const Color(0xFF455A64); // BlueGrey 700

  // --- DA40NG Fleet Database ---
  final List<_Aircraft> _da40Fleet = [
    _Aircraft(registration: 'CUSTOM', emptyWeight: 0, emptyCg: 0), // Special value for custom entry
    // Updated DA40 NG entries (weights in kg, CG in mm)
    _Aircraft(registration: 'CN-PLA', emptyWeight: 974.3, emptyCg: 2.470 * 1000),
    _Aircraft(registration: 'CN-PLB', emptyWeight: 974.4, emptyCg: 2.465 * 1000),
    _Aircraft(registration: 'CN-PLC', emptyWeight: 978.4, emptyCg: 2.474 * 1000),
    _Aircraft(registration: 'CN-PLD', emptyWeight: 981.0, emptyCg: 2.474 * 1000),
    _Aircraft(registration: 'CN-PLN', emptyWeight: 979.5, emptyCg: 2.474 * 1000),
    // Missing data for CN-PLY: use average of provided DA40 entries
    _Aircraft(registration: 'CN-PLY', emptyWeight: 977.52, emptyCg: 2.4714 * 1000),
    // Legacy/fallback entries retained below
    _Aircraft(registration: 'CN-PLE', emptyWeight: 936.8, emptyCg: 2.410 * 1000),
    _Aircraft(registration: 'CN-PLF', emptyWeight: 944.4, emptyCg: 2.410 * 1000),
    _Aircraft(registration: 'CN-PLG', emptyWeight: 944.3, emptyCg: 2.410 * 1000),
    _Aircraft(registration: 'CN-PLH', emptyWeight: 943.8, emptyCg: 2.410 * 1000),
    _Aircraft(registration: 'CN-PLI', emptyWeight: 945.0, emptyCg: 2.410 * 1000),
    _Aircraft(registration: 'CN-PLJ', emptyWeight: 942.2, emptyCg: 2.410 * 1000),
    _Aircraft(registration: 'CN-PLK', emptyWeight: 941.8, emptyCg: 2.410 * 1000),
    _Aircraft(registration: 'CN-PLL', emptyWeight: 938.8, emptyCg: 2.410 * 1000),
    _Aircraft(registration: 'CN-PLW', emptyWeight: 945.0, emptyCg: 2.410 * 1000),
  ];

  late _Aircraft _selectedAircraft;
  _Aircraft? _customAircraft;

  // --- DA42 VI --- 
  final List<_Aircraft> _da42Fleet = [
    _Aircraft(registration: 'CUSTOM', emptyWeight: 0, emptyCg: 0),
    // Provided DA42 VI data (alphabetical order after CUSTOM)
    _Aircraft(registration: 'CN-PLP', emptyWeight: 1456.0, emptyCg: 2.36 * 1000),
    _Aircraft(registration: 'CN-PLQ', emptyWeight: 1450.0, emptyCg: 2.36 * 1000),
    _Aircraft(registration: 'CN-PLR', emptyWeight: 1486.25, emptyCg: 2.35 * 1000), // average (inferred)
    _Aircraft(registration: 'CN-PLS', emptyWeight: 1516.5, emptyCg: 2.41 * 1000),
    _Aircraft(registration: 'CN-PLT', emptyWeight: 1500.0, emptyCg: 2.41 * 1000),
    _Aircraft(registration: 'CN-PLU', emptyWeight: 1486.25, emptyCg: 2.41 * 1000), // average (inferred)
    _Aircraft(registration: 'CN-PLV', emptyWeight: 1486.25, emptyCg: 2.41 * 1000), // average (inferred)
  ];
  late _Aircraft _selectedDA42Aircraft;
  _Aircraft? _customDA42Aircraft;

  static const _da42FrontSeatArm = 2.30 * 1000;
  static const _da42RearSeatArm = 3.25 * 1000;
  static const _da42FuelArm = 3.20 * 1000;
  static const _da42NoseBaggageArm = 0.60 * 1000;
  static const _da42StandardBaggageArm = 3.65 * 1000;
  static const _da42ShortExtensionArm = 3.97 * 1000;
  static const double _da42MaxTakeoffWeight = 1999.0;
  static const double _da42FuelDensity = 0.81; // Jet A-1 kg/L

  final List<FlSpot> _da42CgEnvelope = [
    FlSpot(2.350 * 1000, 1450),
    FlSpot(2.350 * 1000, 1468),
    FlSpot(2.434 * 1000, 1999),
    FlSpot(2.480 * 1000, 1999),
    FlSpot(2.480 * 1000, 1700),
    FlSpot(2.454 * 1000, 1450),
    FlSpot(2.350 * 1000, 1450), // This point is the bottom-left corner
  ];

  final _da42PilotController = TextEditingController();
  final _da42CopilotController = TextEditingController();
  final _da42PaxController = TextEditingController();
  final _da42NoseBaggageController = TextEditingController();
  final _da42StandardBaggageController = TextEditingController();
  final _da42ShortExtensionController = TextEditingController();
  final _da42FuelController = TextEditingController();
  final _da42FuelConsumedController = TextEditingController();

  double _da42TotalWeight = 0;
  double _da42TotalMoment = 0;
  double _da42TotalCg = 0;
  Color _da42WeightColor = Colors.green;
  Color _da42CgColor = Colors.green;
  String _da42Status = 'Within Limits';

  double _da42LandingWeight = 0;
  double _da42LandingCg = 0;
  Color _da42LandingWeightColor = Colors.green;
  Color _da42LandingCgColor = Colors.green;
  String _da42LandingStatus = 'Within Limits';

  // --- DA40NG Station Arms (From User POH) ---
  static const _da40FrontSeatArm = 2.300 * 1000;   // mm
  static const _da40RearSeatArm = 3.250 * 1000;    // mm
  static const _da40BaggageArm = 3.890 * 1000;   // mm
  static const _da40BaggageTubeArm = 4.540 * 1000; // mm
  static const _da40FuelArm = 2.630 * 1000;      // mm

  // --- Fuel Conversion ---
  static const _da40FuelDensity = 0.81;      // kg/L for Jet A-1
  static const _usGalToLiters = 3.78541;    // Conversion factor

  // --- DA40NG Limits (REPLACE WITH YOUR POH VALUES) ---
  static const _da40MaxTakeoffWeight = 1310.0; // kg
  static const List<FlSpot> _da40CgEnvelope = [ // Format: FlSpot(CG_mm, Weight_kg)
    FlSpot(2.40 * 1000, 940),   // Fwd Limit, Low Weight
    FlSpot(2.40 * 1000, 1080),  // Fwd Limit, Mid Weight
    FlSpot(2.469 * 1000, 1310),  // Fwd Limit, Max Weight
    FlSpot(2.53 * 1000, 1310),  // Aft Limit, Max Weight
    FlSpot(2.53 * 1000, 940),   // Aft Limit, Low Weight
  ];

  // --- State Variables ---
  final _da40PilotController = TextEditingController();
  final _da40CopilotController = TextEditingController();
  final _da40PaxController = TextEditingController();
  final _da40BaggageController = TextEditingController();
  final _da40BaggageTubeController = TextEditingController();
  final _da40FuelController = TextEditingController();
  final _da40FuelConsumedController = TextEditingController();

  double _da40TotalWeight = 0;
  double _da40TotalMoment = 0;
  double _da40TotalCg = 0;
  String _da40Status = 'Within Limits';
  Color _da40WeightColor = Colors.green;
  Color _da40CgColor = Colors.green;

  // State variables for Landing
  double _da40LandingWeight = 0;
  double _da40LandingCg = 0;
  Color _da40LandingWeightColor = Colors.green;
  Color _da40LandingCgColor = Colors.green;
  String _da40LandingStatus = 'Within Limits';

  // Maps to hold all calculation results for PDF generation
  Map<String, dynamic> _da40Result = {};
  Map<String, dynamic> _da42Result = {};



  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (_tabController.indexIsChanging) {
          // Do nothing if the tab is still animating.
        } else {
          // The user has selected a new tab.
          // Ensure corresponding calculations run and force a rebuild.
          if (_tabController.index == 0) {
            _calculateDA40();
          } else {
            _calculateDA42();
          }
          // Force a repaint with a new chart key, and ensure it happens after layout.
          setState(() { _chartVersion++; });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        }
      });
    _selectedAircraft = _da40Fleet[1]; // Default to the first real aircraft
    _selectedDA42Aircraft = _da42Fleet[1];

    // Add listeners
    _da40PilotController.addListener(_calculateDA40);
    _da40CopilotController.addListener(_calculateDA40);
    _da40PaxController.addListener(_calculateDA40);
    _da40BaggageController.addListener(_calculateDA40);
    _da40BaggageTubeController.addListener(_calculateDA40);
    _da40FuelController.addListener(_calculateDA40);
    _da40FuelConsumedController.addListener(_calculateDA40);
    _calculateDA40(); // Initial calculation

    _da42PilotController.addListener(_calculateDA42);
    _da42CopilotController.addListener(_calculateDA42);
    _da42PaxController.addListener(_calculateDA42);
    _da42NoseBaggageController.addListener(_calculateDA42);
    _da42StandardBaggageController.addListener(_calculateDA42);
    _da42ShortExtensionController.addListener(_calculateDA42);
    _da42FuelController.addListener(_calculateDA42);
    _da42FuelConsumedController.addListener(_calculateDA42);
    _calculateDA42();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _da40PilotController.dispose();
    _da40CopilotController.dispose();
    _da40PaxController.dispose();
    _da40BaggageController.dispose();
    _da40BaggageTubeController.dispose();
    _da40FuelConsumedController.dispose();
    _da40FuelController.dispose();

    _da42PilotController.dispose();
    _da42CopilotController.dispose();
    _da42PaxController.dispose();
    _da42NoseBaggageController.dispose();
    _da42StandardBaggageController.dispose();
    _da42ShortExtensionController.dispose();
    _da42FuelController.dispose();
    _da42FuelConsumedController.dispose();
    super.dispose();
  }

  void _calculateDA40() {
    final pilot = double.tryParse(_da40PilotController.text) ?? 0.0;
    final copilot = double.tryParse(_da40CopilotController.text) ?? 0.0;
    final pax = double.tryParse(_da40PaxController.text) ?? 0.0;
    final baggage = double.tryParse(_da40BaggageController.text) ?? 0.0;
    final baggageTube = double.tryParse(_da40BaggageTubeController.text) ?? 0.0;
    final fuelGallons = double.tryParse(_da40FuelController.text) ?? 0.0;
    final fuelWeight = fuelGallons * _usGalToLiters * _da40FuelDensity;
    final fuelConsumedGallons = double.tryParse(_da40FuelConsumedController.text) ?? 0.0;
    final fuelConsumedWeight = fuelConsumedGallons * _usGalToLiters * _da40FuelDensity;

    final aircraft = _customAircraft ?? _selectedAircraft;
    final frontSeatsWeight = pilot + copilot;
    final totalBaggageWeight = baggage + baggageTube;

    final zeroFuelWeight = aircraft.emptyWeight + frontSeatsWeight + pax + totalBaggageWeight;
    final takeoffWeight = zeroFuelWeight + fuelWeight;

    final zeroFuelMoment = aircraft.emptyMoment +
        (frontSeatsWeight * _da40FrontSeatArm) +
        (pax * _da40RearSeatArm) +
        (baggage * _da40BaggageArm) +
        (baggageTube * _da40BaggageTubeArm);
    
    final takeoffMoment = zeroFuelMoment + (fuelWeight * _da40FuelArm);

    // --- Takeoff Validation ---
    bool isTakeoffWeightOk = takeoffWeight <= _da40MaxTakeoffWeight;
    final takeoffCg = takeoffWeight > 0 ? takeoffMoment / takeoffWeight : 0.0;
    bool isTakeoffCgOk = _isPointInPolygon(FlSpot(takeoffCg, takeoffWeight), _da40CgEnvelope);

    String takeoffStatus = 'Within Limits';
    if (!isTakeoffWeightOk) {
      takeoffStatus = 'OVERWEIGHT';
    } else if (!isTakeoffCgOk) {
      takeoffStatus = 'CG OUT OF LIMITS';
    }

    // --- Landing Calculation & Validation ---
    final landingWeight = takeoffWeight - fuelConsumedWeight;
    final landingMoment = takeoffMoment - (fuelConsumedWeight * _da40FuelArm);
    final landingCg = landingWeight > 0 ? landingMoment / landingWeight : 0.0;

    bool isLandingWeightOk = landingWeight <= _da40MaxTakeoffWeight; // Assuming same max weight limit
    bool isLandingCgOk = _isPointInPolygon(FlSpot(landingCg, landingWeight), _da40CgEnvelope);

    String landingStatus = 'Within Limits';
    if (!isLandingWeightOk) {
      landingStatus = 'OVERWEIGHT';
    } else if (!isLandingCgOk) {
      landingStatus = 'CG OUT OF LIMITS';
    }

    setState(() {
      // Update UI state variables
      _da40TotalWeight = takeoffWeight;
      _da40TotalCg = takeoffCg;
      _da40WeightColor = isTakeoffWeightOk ? Colors.green : Colors.red;
      _da40CgColor = isTakeoffCgOk ? Colors.green : Colors.red;
      _da40Status = takeoffStatus;

      _da40LandingWeight = landingWeight;
      _da40LandingCg = landingCg;
      _da40LandingWeightColor = isLandingWeightOk ? Colors.green : Colors.red;
      _da40LandingCgColor = isLandingCgOk ? Colors.green : Colors.red;
      _da40LandingStatus = landingStatus;

      // Store all results in the map for PDF generation
      _da40Result = {
        'frontSeatsWeight': frontSeatsWeight,
        'rearSeatsWeight': pax,
        'baggageWeight': totalBaggageWeight,
        'takeoffWeight': takeoffWeight,
        'takeoffCg': takeoffCg,
        'takeoffStatus': takeoffStatus,
        'landingWeight': landingWeight,
        'landingCg': landingCg,
        'landingStatus': landingStatus,
      };
      _chartVersion++;
    });
  }

  void _calculateDA42() {
    final pilot = double.tryParse(_da42PilotController.text) ?? 0.0;
    final copilot = double.tryParse(_da42CopilotController.text) ?? 0.0;
    final pax = double.tryParse(_da42PaxController.text) ?? 0.0;
    final noseBaggage = double.tryParse(_da42NoseBaggageController.text) ?? 0.0;
    final standardBaggage = double.tryParse(_da42StandardBaggageController.text) ?? 0.0;
    final shortExtension = double.tryParse(_da42ShortExtensionController.text) ?? 0.0;
    final fuelGallons = double.tryParse(_da42FuelController.text) ?? 0.0;
    final fuelWeight = fuelGallons * _usGalToLiters * _da42FuelDensity;
    final fuelConsumedGallons = double.tryParse(_da42FuelConsumedController.text) ?? 0.0;
    final fuelConsumedWeight = fuelConsumedGallons * _usGalToLiters * _da42FuelDensity;

    final aircraft = _customDA42Aircraft ?? _selectedDA42Aircraft;
    final frontSeatsWeight = pilot + copilot;
    final totalBaggageWeight = standardBaggage + shortExtension; // Nose baggage is separate

    final zeroFuelWeight = aircraft.emptyWeight + frontSeatsWeight + pax + noseBaggage + totalBaggageWeight;
    final takeoffWeight = zeroFuelWeight + fuelWeight;

    final zeroFuelMoment = aircraft.emptyMoment +
        (frontSeatsWeight * _da42FrontSeatArm) +
        (pax * _da42RearSeatArm) +
        (noseBaggage * _da42NoseBaggageArm) +
        (standardBaggage * _da42StandardBaggageArm) +
        (shortExtension * _da42ShortExtensionArm);

    final takeoffMoment = zeroFuelMoment + (fuelWeight * _da42FuelArm);

    // --- Takeoff Validation ---
    final takeoffCg = takeoffWeight > 0 ? takeoffMoment / takeoffWeight : 0.0;
    bool isTakeoffWeightOk = takeoffWeight <= _da42MaxTakeoffWeight;
    bool isTakeoffCgOk = _isPointInPolygon(FlSpot(takeoffCg, takeoffWeight), _da42CgEnvelope);

    String takeoffStatus = 'Within Limits';
    if (!isTakeoffWeightOk) {
      takeoffStatus = 'OVERWEIGHT';
    } else if (!isTakeoffCgOk) {
      takeoffStatus = 'CG OUT OF LIMITS';
    }

    // --- Landing Calculation & Validation ---
    final landingWeight = takeoffWeight - fuelConsumedWeight;
    final landingMoment = takeoffMoment - (fuelConsumedWeight * _da42FuelArm);
    final landingCg = landingWeight > 0 ? landingMoment / landingWeight : 0.0;

    bool isLandingWeightOk = landingWeight <= _da42MaxTakeoffWeight;
    bool isLandingCgOk = _isPointInPolygon(FlSpot(landingCg, landingWeight), _da42CgEnvelope);

    String landingStatus = 'Within Limits';
    if (!isLandingWeightOk) {
      landingStatus = 'OVERWEIGHT';
    } else if (!isLandingCgOk) {
      landingStatus = 'CG OUT OF LIMITS';
    }

    setState(() {
      // Update UI state variables
      _da42TotalWeight = takeoffWeight;
      _da42TotalCg = takeoffCg;
      _da42TotalMoment = takeoffMoment;
      _da42WeightColor = isTakeoffWeightOk ? Colors.green : Colors.red;
      _da42CgColor = isTakeoffCgOk ? Colors.green : Colors.red;
      _da42Status = takeoffStatus;

      _da42LandingWeight = landingWeight;
      _da42LandingCg = landingCg;
      _da42LandingWeightColor = isLandingWeightOk ? Colors.green : Colors.red;
      _da42LandingCgColor = isLandingCgOk ? Colors.green : Colors.red;
      _da42LandingStatus = landingStatus;

      // Store all results in the map for PDF generation
      _da42Result = {
        'frontSeatsWeight': frontSeatsWeight,
        'rearSeatsWeight': pax,
        'noseBaggageWeight': noseBaggage,
        'baggageWeight': totalBaggageWeight,
        'takeoffWeight': takeoffWeight,
        'takeoffCg': takeoffCg,
        'takeoffStatus': takeoffStatus,
        'landingWeight': landingWeight,
        'landingCg': landingCg,
        'landingStatus': landingStatus,
      };
    });
  }

  Widget _buildDA40Calculator({bool showResults = true}) {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildAircraftSelector('Select DA40 NG Aircraft', _da40Fleet, _selectedAircraft, (newValue) {
          if (newValue != null) {
            if (newValue.registration == 'CUSTOM') {
              _showCustomAircraftDialog();
            } else {
              setState(() {
                _selectedAircraft = newValue;
                _customAircraft = null;
                _calculateDA40();
              });
            }
          }
        }),
        const SizedBox(height: 24),
        _buildSectionTitle('Load Stations', color: _chartPrimaryColor),
        _buildWeightInputRow('Pilot', _da40PilotController, 'kg'),
        _buildWeightInputRow('Co-pilot', _da40CopilotController, 'kg'),
        _buildWeightInputRow('Rear Passengers', _da40PaxController, 'kg'),
        _buildWeightInputRow('Baggage', _da40BaggageController, 'kg'),
        _buildWeightInputRow('Baggage Tube', _da40BaggageTubeController, 'kg'),
        _buildWeightInputRow('Fuel', _da40FuelController, 'US Gal'),
        _buildWeightInputRow('Fuel to be Consumed', _da40FuelConsumedController, 'US Gal'),
        if (showResults) ...[
          const SizedBox(height: 24),
          Text(_da40Status, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: _da40Status == 'Within Limits' ? Colors.green : Colors.red), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          _buildResultTable('Takeoff', _da40TotalWeight, _da40TotalCg, _da40WeightColor, _da40CgColor, _da40Status),
          const SizedBox(height: 16),
          _buildResultTable('Landing', _da40LandingWeight, _da40LandingCg, _da40LandingWeightColor, _da40LandingCgColor, _da40LandingStatus),
          const SizedBox(height: 24),
          SizedBox(
            height: 600,
            child: _buildCgChart(
              'DA40 NG',
              _da40CgEnvelope.map((s) => FlSpot(s.x / 1000, s.y)).toList(),
              _da40TotalCg / 1000,
              _da40TotalWeight,
              _da40LandingCg / 1000,
              _da40LandingWeight,
              2.400, // xMin
              2.550, // xMax
              940, // yMin
              1360, // yMax
            ),
          ),
        ],
      ],
    );
  }

  Future<Uint8List?> _captureChartPng({double pixelRatio = 3.0}) async {
    try {
      final GlobalKey key = _tabController.index == 0 ? _chartRepaintKeyDa40 : _chartRepaintKeyDa42;
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[WB] Chart capture failed: $e');
      return null;
    }
  }

  Widget _buildDA42Calculator({bool showResults = true}) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildAircraftSelector('Select DA42 VI Aircraft', _da42Fleet, _selectedDA42Aircraft, (newValue) {
              if (newValue != null) {
                if (newValue.registration == 'CUSTOM') {
                  _showCustomDA42AircraftDialog();
                } else {
                  setState(() {
                    _selectedDA42Aircraft = newValue;
                    _customDA42Aircraft = null;
                    _calculateDA42();
                  });
                }
              }
            }),
            const SizedBox(height: 24),
            _buildSectionTitle('Load Stations', color: _chartPrimaryColor),
            _buildWeightInputRow('Pilot', _da42PilotController, 'kg'),
            _buildWeightInputRow('Co-pilot', _da42CopilotController, 'kg'),
            _buildWeightInputRow('Rear Passengers', _da42PaxController, 'kg'),
            _buildWeightInputRow('Nose Baggage', _da42NoseBaggageController, 'kg'),
            _buildWeightInputRow('Standard Baggage', _da42StandardBaggageController, 'kg'),
            _buildWeightInputRow('Short Extension', _da42ShortExtensionController, 'kg'),
            _buildWeightInputRow('Fuel', _da42FuelController, 'US Gal'),
            _buildWeightInputRow('Fuel to be Consumed', _da42FuelConsumedController, 'US Gal'),
            if (showResults) ...[
              const SizedBox(height: 24),
              Text(_da42Status, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: _da42Status == 'Within Limits' ? Colors.green : Colors.red), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              _buildResultTable('Takeoff', _da42TotalWeight, _da42TotalCg, _da42WeightColor, _da42CgColor, _da42Status),
              const SizedBox(height: 16),
              _buildResultTable('Landing', _da42LandingWeight, _da42LandingCg, _da42LandingWeightColor, _da42LandingCgColor, _da42LandingStatus),
              const SizedBox(height: 24),
              SizedBox(
                height: 600,
                child: _buildCgChart(
              'DA42 VI',
              _da42CgEnvelope.map((s) => FlSpot(s.x / 1000, s.y)).toList(),
              _da42TotalCg / 1000,
              _da42TotalWeight,
              _da42LandingCg / 1000,
              _da42LandingWeight,
              2.350, // xMin
              2.500, // xMax
              1450, // yMin
              2050, // yMax
            ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    final bool isDesktop = !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.macOS);
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: const Color(0xFFF5F5F5), // neutral light grey
        iconTheme: const IconThemeData(color: Colors.black87),
        textTheme: GoogleFonts.montserratTextTheme(ThemeData.light().textTheme)
            .apply(bodyColor: Colors.black87, displayColor: Colors.black87),
        tabBarTheme: TabBarThemeData(
          labelColor: Colors.black87,
          unselectedLabelColor: Colors.black54,
          labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.montserrat(),
          indicatorColor: const Color(0xFF1976D2),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Stack(
          children: [
            if (isDesktop)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AppWindowBar(
                  buttonColors: WindowButtonColors(
                    iconNormal: Colors.black87,
                    iconMouseOver: Colors.black,
                    iconMouseDown: Colors.black,
                    mouseOver: Colors.black12,
                    mouseDown: Colors.black26,
                  ),
                  closeButtonColors: WindowButtonColors(
                    iconNormal: Colors.black87,
                    iconMouseOver: Colors.white,
                    mouseOver: const Color(0xFFE57373),
                    mouseDown: const Color(0xFFD32F2F),
                  ),
                ),
              ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.0, 16.0 + (isDesktop ? AppWindowBar.height : 0), 16.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Text(
                            'Masse et Centrage',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 22, color: Colors.black87),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TabBar(
                      controller: _tabController,
                      labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 14),
                      unselectedLabelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w500, fontSize: 14),
                      indicatorColor: _chartPrimaryColor,
                      labelColor: _chartPrimaryColor,
                      unselectedLabelColor: Colors.black54,
                      indicatorWeight: 3,
                      tabs: const [
                        Tab(text: 'DA40 NG'),
                        Tab(text: 'DA42 VI'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          isWide ? _buildWideLayoutFor(true) : _buildNarrowLayoutFor(true),
                          isWide ? _buildWideLayoutFor(false) : _buildNarrowLayoutFor(false),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildNavigationButtons(context),
      ),
    );
  }

  Widget _buildNavigationButtons(BuildContext context) {
    bool isLast = NavigationService.isLastScreen('Masse et Centrage', widget.selectedItems);
    final bool isDesktop = !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.macOS);
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16.0,
        isDesktop ? 16.0 : 20.0,
        16.0,
        (isDesktop ? 16.0 : 24.0) + (isDesktop ? 0.0 : bottomInset),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade300,
                minimumSize: const Size(double.infinity, 50),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Quitter',
                style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                // First, generate the balance sheet PDF
                final image = await _captureChartPng();
                if (image == null) return; // Handle error if capture fails

                final data = _getAircraftDataForPdf();
                data['chartImage'] = image;

                final balanceSheetBytes = await _balanceSheetPdfService.createBalanceSheetPdf(data);

                // Then, navigate to the next screen with the generated bytes
                final route = NavigationService.getNextScreenRoute(
                  context: context,
                  currentScreen: 'Masse et Centrage',
                  selectedItems: widget.selectedItems,
                  airportCodes: widget.airportCodes,
                  navLogPath: widget.navLogPath,
                  navLogBytes: widget.navLogBytes,
                  flightPlanPath: widget.flightPlanPath,
                  flightPlanBytes: widget.flightPlanBytes,
                  balanceSheetBytes: balanceSheetBytes, // Pass the generated bytes
                  selectedTemsiCharts: widget.selectedTemsiCharts,
                  selectedWintemCharts: widget.selectedWintemCharts,
                  notams: widget.notams,
                );

                if (route != null && mounted) {
                  Navigator.push(context, route);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                minimumSize: const Size(double.infinity, 50),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isLast ? 'Generate Dossier' : 'Continue',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndShowPdf() async {
    final image = await _captureChartPng();
    if (image == null) {
      return;
    }

    final data = _getAircraftDataForPdf();
    data['chartImage'] = image; // Add the captured image to the data map

    final pdfBytes = await _balanceSheetPdfService.createBalanceSheetPdf(data);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BalanceSheetViewerScreen(
            pdfBytes: pdfBytes,
            selectedItems: widget.selectedItems,
            airportCodes: widget.airportCodes,
            flightPlanPath: widget.flightPlanPath,
            selectedTemsiCharts: widget.selectedTemsiCharts,
            selectedWintemCharts: widget.selectedWintemCharts,
            notams: widget.notams,
          ),
        ),
      );
    }
  }

  Widget _buildNarrowLayoutFor(bool isDA40) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pass showResults: false to prevent the calculator from building its own chart.
            isDA40
                ? _buildDA40Calculator(showResults: false)
                : SingleChildScrollView(
                    child: _buildDA42Calculator(showResults: false),
                  ),
            const SizedBox(height: 24),
            _buildTakeoffResultsTableFor(isDA40),
            const SizedBox(height: 16),
            _buildLandingResultsTableFor(isDA40),
            const SizedBox(height: 24),
            _buildChartPanelFor(isDA40),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayoutFor(bool isDA40) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                isDA40
                    ? _buildDA40Calculator(showResults: false)
                    : _buildDA42Calculator(showResults: false),
                const SizedBox(height: 24),
                _buildTakeoffResultsTableFor(isDA40),
              ],
            ),
          ),
        ),
        // Right Column
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildLandingResultsTableFor(isDA40),
                const SizedBox(height: 24),
                _buildChartPanelFor(isDA40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTakeoffResultsTableFor(bool isDA40) {
    return _buildResultTable(
      'Takeoff',
      isDA40 ? _da40TotalWeight : _da42TotalWeight,
      isDA40 ? _da40TotalCg : _da42TotalCg,
      isDA40 ? _da40WeightColor : _da42WeightColor,
      isDA40 ? _da40CgColor : _da42CgColor,
      isDA40 ? _da40Status : _da42Status,
      titleColor: _chartTakeoffColor,
    );
  }

  Widget _buildLandingResultsTableFor(bool isDA40) {
    return _buildResultTable(
      'Landing',
      isDA40 ? _da40LandingWeight : _da42LandingWeight,
      isDA40 ? _da40LandingCg : _da42LandingCg,
      isDA40 ? _da40LandingWeightColor : _da42LandingWeightColor,
      isDA40 ? _da40LandingCgColor : _da42LandingCgColor,
      isDA40 ? _da40LandingStatus : _da42LandingStatus,
      titleColor: Colors.green,
    );
  }

  Widget _buildChartPanelFor(bool isDA40) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.macOS);
        final double maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.of(context).size.width;
        // On mobile/tablet, set height relative to width for responsiveness; keep 600 on desktop
        final double chartHeight = isDesktop ? 600 : maxW * 0.75.clamp(0.0, 9999.0);
        final double clampedHeight = chartHeight.clamp(280, 420); // reasonable mobile range
        return Column(
          children: [
            SizedBox(
              key: ValueKey<String>('cg-chart-${isDA40 ? 'da40' : 'da42'}-v$_chartVersion'),
              width: double.infinity,
              height: isDesktop ? 600 : clampedHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black12, width: 1),
                ),
                child: RepaintBoundary(
                  key: isDA40 ? _chartRepaintKeyDa40 : _chartRepaintKeyDa42,
                  child: _buildCgChart(
                    isDA40 ? 'DA40 NG' : 'DA42 VI',
                    (isDA40 ? _da40CgEnvelope : _da42CgEnvelope).map((s) => FlSpot(s.x / 1000, s.y)).toList(),
                    (isDA40 ? _da40TotalCg : _da42TotalCg) / 1000,
                    isDA40 ? _da40TotalWeight : _da42TotalWeight,
                    (isDA40 ? _da40LandingCg : _da42LandingCg) / 1000,
                    isDA40 ? _da40LandingWeight : _da42LandingWeight,
                    (isDA40 ? 2.400 : 2.350), // xMin
                    (isDA40 ? 2.550 : 2.500), // xMax
                    isDA40 ? 940 : 1450, // yMin
                    isDA40 ? 1360 : 2050, // yMax,
                    chartKey: ValueKey<String>(
                      'line-${isDA40 ? 'da40' : 'da42'}-${(isDA40 ? _da40TotalCg : _da42TotalCg).toStringAsFixed(3)}-${(isDA40 ? _da40TotalWeight : _da42TotalWeight).toStringAsFixed(1)}-${(isDA40 ? _da40LandingCg : _da42LandingCg).toStringAsFixed(3)}-${(isDA40 ? _da40LandingWeight : _da42LandingWeight).toStringAsFixed(1)}'
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildChartLegend(),
          ],
        );
      },
    );
  }

  Widget _buildChartLegend() {
    return Wrap(
      spacing: 24.0,
      runSpacing: 8.0,
      alignment: WrapAlignment.center,
      children: [
        _buildLegendItem(_chartEnvelopeColor, 'CG Envelope'),
        _buildLegendItem(_chartTakeoffColor, 'Takeoff Point'),
        _buildLegendItem(_chartLandingColor, 'Landing Point'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w600, color: color ?? Colors.blueGrey.shade800),
      ),
    );
  }

  Widget _buildWeightInputRow(String label, TextEditingController controller, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label, style: GoogleFonts.montserrat(fontSize: 16))),
          Expanded(
            flex: 2,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 50, child: Text(unit, style: GoogleFonts.montserrat(color: Colors.grey[600]))),
        ],
      ),
    );
  }

  Widget _buildResultTable(String title, double weight, double cg, Color weightColor, Color cgColor, String status, {Color? titleColor}) {
    Color statusColor;
    switch (status) {
      case 'OVERWEIGHT':
      case 'CG OUT OF LIMITS':
      case 'CG OUT OF FWD LIMIT':
      case 'CG OUT OF AFT LIMIT':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor ?? Colors.black87)),
          const SizedBox(height: 8),
          _buildResultRow('Total Weight', '${weight.toStringAsFixed(1)} kg', weightColor),
          _buildResultRow('Center of Gravity', '${(cg / 1000).toStringAsFixed(3)} m', cgColor),
          const SizedBox(height: 8),
          Center(
            child: Text(
              status,
              style: GoogleFonts.montserrat(color: statusColor, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w500)),
          Text(value, style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

Widget _buildCgChart(
    String title,
    List<FlSpot> envelope,
    double totalCg,
    double totalWeight,
    double landingCg,
    double landingWeight,
    double xMin,
    double xMax,
    double yMin,
    double yMax,
    {Key? chartKey}
  ) {
    debugPrint('[WB] Chart "$title" v${_chartVersion} range x:[${xMin.toStringAsFixed(3)}, ${xMax.toStringAsFixed(3)}] y:[${yMin.toStringAsFixed(0)}, ${yMax.toStringAsFixed(0)}]');
    debugPrint('[WB] Points: env=${envelope.length} takeoff=(${totalCg.toStringAsFixed(3)}, ${totalWeight.toStringAsFixed(1)}) landing=(${landingCg.toStringAsFixed(3)}, ${landingWeight.toStringAsFixed(1)})');
    // Fallback rendering if data is invalid to help detect blank states.
    final bool invalid = envelope.isEmpty ||
        totalCg.isNaN || totalWeight.isNaN || landingCg.isNaN || landingWeight.isNaN ||
        xMin.isNaN || xMax.isNaN || yMin.isNaN || yMax.isNaN || xMin >= xMax || yMin >= yMax;
    if (invalid) {
      return Container(
        alignment: Alignment.center,
        color: Colors.transparent,
        child: Text(
          'No chart data',
          style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w600),
        ),
      );
    }
    // --- Professional Color Palette ---
    const primaryColor = Color(0xFF0D47A1); // Deep, professional blue
    const accentColor = Color(0xFF4CAF50); // Clear green for takeoff
    const warningColor = Color(0xFFD32F2F); // Clear red for landing
    const gridColor = Color(0xFFBDBDBD); // Softer grey for grid
    const textColor = Color(0xFF424242); // Dark grey for text
    const envelopeFillColor = Color(0xFFE3F2FD); // Light blue for envelope fill
    const envelopeBorderColor = Color(0xFF42A5F5); // Brighter blue for envelope border

    final takeOffSpot = FlSpot(totalCg, totalWeight);
    final landingSpot = FlSpot(landingCg, landingWeight);
    // Determine the maximum landing weight from the envelope (highest Y within envelope)
    final double maxLandingWeight = envelope.map((e) => e.y).fold<double>(envelope.first.y, (prev, e) => e > prev ? e : prev);

    // Ensure the envelope is a closed polygon for filling.
    final List<FlSpot> closedEnvelope = List.from(envelope);
    if (envelope.isNotEmpty && (envelope.first.x != envelope.last.x || envelope.first.y != envelope.last.y)) {
      closedEnvelope.add(envelope.first);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Estimate plot paddings to map data Y -> pixel Y for overlay badge
        const double leftTitlesW = 50;   // matches reservedSize in left axis
        const double topTitlesH = 40;    // matches axisNameSize (title at top)
        const double bottomTitlesH = 40; // matches reservedSize in bottom axis
        final double plotHeight = (constraints.maxHeight - topTitlesH - bottomTitlesH).clamp(0, constraints.maxHeight);

        // Responsive scaling based on chart width/height (better on phones)
        final double w = constraints.maxWidth.isFinite ? constraints.maxWidth : 600.0;
        final double base = [w, plotHeight * 1.2].where((v) => v.isFinite).reduce((a, b) => a < b ? a : b);
        final double scale = (base / 600.0).clamp(0.95, 1.15);
        final double badgeFontSize = (11.0 * scale).clamp(10.0, 12.0);
        final double badgeHPad = (10.0 * scale).clamp(8.0, 12.0);
        final double badgeVPad = (5.0 * scale).clamp(4.0, 7.0);
        final double arrowSize = (16.0 * scale).clamp(14.0, 18.0);
        final double connectorLen = (12.0 * scale).clamp(10.0, 16.0);
        final double trailingIntoPlot = (4.0 * scale).clamp(3.0, 6.0); // ensures the tip overlaps into plot
        final double borderRadius = (6.0 * scale).clamp(5.0, 8.0);

        // y fraction from top of plot (0 at top, 1 at bottom)
        final double yFrac = 1.0 - ((maxLandingWeight - yMin) / (yMax - yMin)).clamp(0.0, 1.0);
        // Estimate badge height to center it vertically on the Y level more accurately
        final double estimatedBadgeHeight = badgeVPad * 2 + badgeFontSize * 1.2;
        final double badgeTop = topTitlesH + yFrac * plotHeight - (estimatedBadgeHeight / 2);
        // place the badge just inside the chart's left axis area (after left titles and 1px border)
        final double plotLeft = leftTitlesW + 1.0; // account for chart border width
        final double badgeLeft = plotLeft + 12.0 * scale; // clearer placement inside the plot

        return Stack(
          children: [
            Positioned.fill(
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((barSpot) {
                          final flSpot = barSpot;
                          String? label;
                          // Identify by color; envelope gets no tooltip
                          if (barSpot.bar.color == _chartTakeoffColor) {
                            label = 'Takeoff';
                          } else if (barSpot.bar.color == _chartLandingColor) {
                            label = 'Landing';
                          }
                          if (label == null) {
                            return null; // hide tooltip for envelope
                          }
                          return LineTooltipItem(
                            '$label\n${flSpot.y.toStringAsFixed(1)} kg\n${flSpot.x.toStringAsFixed(3)} m',
                            GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.left,
                          );
                        }).whereType<LineTooltipItem>().toList();
                      },
                    ),
                  ),

                  // --- Grid Styling ---
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    drawHorizontalLine: true,
                    verticalInterval: (xMax - xMin) / 4,
                    horizontalInterval: (yMax - yMin) / 5,
                    getDrawingVerticalLine: (value) => FlLine(
                      color: _chartGridColor,
                      strokeWidth: 0.5,
                      dashArray: [4, 4], // Dashed lines
                    ),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: _chartGridColor,
                      strokeWidth: 0.5,
                      dashArray: [4, 4], // Dashed lines
                    ),
                  ),

                  // --- Title and Axis Styling ---
                  titlesData: FlTitlesData(
                    show: true,
                    // Chart Title
                    topTitles: AxisTitles(
                      sideTitles: const SideTitles(showTitles: false),
                      axisNameWidget: Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          '$title - Center of Gravity Envelope',
                          style: GoogleFonts.poppins(
                            color: _chartPrimaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      axisNameSize: 40,
                    ),
                    // Bottom (X-Axis) Titles
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: (xMax - xMin) / 4,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            value.toStringAsFixed(3),
                            style: GoogleFonts.poppins(color: _chartTextColor, fontWeight: FontWeight.w500, fontSize: 11),
                          ),
                        ),
                      ),
                      axisNameWidget: Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text(
                          'Center of Gravity (m)',
                          style: GoogleFonts.poppins(color: _chartTextColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      axisNameSize: 40,
                    ),
                    // Left (Y-Axis) Titles
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: leftTitlesW,
                        interval: (yMax - yMin) / 5,
                        getTitlesWidget: (value, meta) {
                          // Only show a single label at the very top (yMax) to reduce clutter
                          const double eps = 0.0001;
                          final bool isTop = (value >= (yMax - eps));
                          if (!isTop) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              yMax.toStringAsFixed(0),
                              style: GoogleFonts.poppins(color: _chartTextColor, fontWeight: FontWeight.w600, fontSize: 11),
                              textAlign: TextAlign.right,
                            ),
                          );
                        },
                      ),
                      axisNameWidget: Text(
                        'Weight (kg)',
                        style: GoogleFonts.poppins(color: _chartTextColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      axisNameSize: 30,
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),

                  // --- Border Styling ---
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: _chartGridColor, width: 1),
                  ),

                  // --- Axis Range ---
                  minX: xMin,
                  maxX: xMax,
                  minY: yMin,
                  maxY: yMax,


                  // --- Data Series ---
                  lineBarsData: [
                    // Envelope Area
                    LineChartBarData(
                      spots: closedEnvelope,
                      isCurved: false,
                      color: _chartEnvelopeBorderColor, // Darker blue for border
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _chartEnvelopeColor.withOpacity(0.3), // Lighter blue for fill
                      ),
                    ),
                    // Takeoff Point
                    LineChartBarData(
                      spots: [takeOffSpot],
                      color: _chartTakeoffColor,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 7,
                          color: _chartTakeoffColor,
                          strokeColor: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    // Landing Point
                    LineChartBarData(
                      spots: [landingSpot],
                      color: _chartLandingColor,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 7,
                          color: _chartLandingColor,
                          strokeColor: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ],
                ),
                key: chartKey,
              ),
            ),

            // Overlay rectangle badge positioned just inside the chart axis with a centered connector and arrow into the plot
            Positioned(
              left: badgeLeft,
              top: badgeTop,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: badgeHPad, vertical: badgeVPad),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _chartLandingColor, width: 1.2),
                      borderRadius: BorderRadius.circular(borderRadius),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Text(
                      'Max landing weight ${maxLandingWeight.toStringAsFixed(0)} kg',
                      style: GoogleFonts.poppins(
                        color: _chartLandingColor,
                        fontWeight: FontWeight.w700,
                        fontSize: badgeFontSize,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: (badgeVPad * 2 + badgeFontSize * 1.2),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: connectorLen, height: 2, color: _chartLandingColor),
                          Icon(Icons.arrow_right, size: arrowSize, color: _chartLandingColor),
                          Container(width: trailingIntoPlot, height: 2, color: _chartLandingColor),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }


  Widget _buildAircraftSelector(String title, List<_Aircraft> fleet, _Aircraft selectedAircraft, ValueChanged<_Aircraft?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0), // Reduced padding
          child: Text(
            title,
            style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w500), // Slightly smaller title
          ),
        ),
        DropdownButtonFormField<_Aircraft>(
          value: selectedAircraft,
          isExpanded: true,
          dropdownColor: Colors.white,
          iconEnabledColor: const Color(0xFF1976D2),
          iconDisabledColor: Colors.grey,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: const BorderSide(color: Color(0xFF1976D2), width: 1.5),
            ),
          ),
          items: fleet.map((_Aircraft aircraft) {
            return DropdownMenuItem<_Aircraft>(
              value: aircraft,
              child: Text(
                aircraft.registration == 'CUSTOM' ? 'Custom / Enter Manually...' : aircraft.registration,
                style: GoogleFonts.montserrat(color: Colors.black87),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Map<String, dynamic> _getAircraftDataForPdf() {
    final isDA40 = _tabController.index == 0;

    if (isDA40) {
      final aircraft = _customAircraft ?? _selectedAircraft;
      return {
        'aircraftType': 'DA40 NG',
        'registration': aircraft.registration,
        'emptyWeight': aircraft.emptyWeight,
        'emptyCg': aircraft.emptyCg,
        'fuelType': 'JET A1',
        'results': _da40Result, // Use the new result map
        'cgEnvelope': _da40CgEnvelope.map((spot) => {'cg': spot.x, 'weight': spot.y}).toList()
      };
    } else {
      final aircraft = _customDA42Aircraft ?? _selectedDA42Aircraft;
      return {
        'aircraftType': 'DA42 VI',
        'registration': aircraft.registration,
        'emptyWeight': aircraft.emptyWeight,
        'emptyCg': aircraft.emptyCg,
        'fuelType': 'JET A1',
        'results': _da42Result, // Use the new result map
        'cgEnvelope': _da42CgEnvelope.map((spot) => {'cg': spot.x, 'weight': spot.y}).toList()
      };
    }
  }

  void _showCustomAircraftDialog() {
    final regController = TextEditingController();
    final weightController = TextEditingController();
    final cgController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Custom DA40 NG Data'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: regController,
                decoration: InputDecoration(labelText: 'Registration (Immatriculation)'),
                textCapitalization: TextCapitalization.characters,
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: weightController,
                decoration: InputDecoration(labelText: 'Empty Weight (kg)'),
                keyboardType: TextInputType.number,
                validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: cgController,
                decoration: InputDecoration(labelText: 'Empty CG (m)'),
                keyboardType: TextInputType.number,
                validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                setState(() {
                  _customAircraft = _Aircraft(
                    registration: regController.text.trim().toUpperCase(),
                    emptyWeight: double.parse(weightController.text),
                    emptyCg: double.parse(cgController.text) * 1000, // Convert m to mm
                  );
                  _selectedAircraft = _da40Fleet.firstWhere((a) => a.registration == 'CUSTOM');
                  _calculateDA40();
                });
                Navigator.pop(context);
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCustomDA42AircraftDialog() {
    final regController = TextEditingController();
    final weightController = TextEditingController();
    final cgController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Custom DA42 VI Data'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: regController,
                decoration: InputDecoration(labelText: 'Registration (Immatriculation)'),
                textCapitalization: TextCapitalization.characters,
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: weightController,
                decoration: InputDecoration(labelText: 'Empty Weight (kg)'),
                keyboardType: TextInputType.number,
                validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: cgController,
                decoration: InputDecoration(labelText: 'Empty CG (m)'),
                keyboardType: TextInputType.number,
                validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                setState(() {
                  _customDA42Aircraft = _Aircraft(
                    registration: regController.text.trim().toUpperCase(),
                    emptyWeight: double.parse(weightController.text),
                    emptyCg: double.parse(cgController.text) * 1000, // Convert m to mm
                  );
                  _selectedDA42Aircraft = _da42Fleet.firstWhere((a) => a.registration == 'CUSTOM');
                  _calculateDA42();
                });
                Navigator.pop(context);
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  bool _isPointInPolygon(FlSpot point, List<FlSpot> polygon) {
    int i, j = polygon.length - 1;
    bool isInside = false;
    for (i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[j];

      // Check if the point is on the edge
      // Using a small tolerance for floating point comparisons
      const double tolerance = 1e-9;
      double dist = (p2.x - p1.x) * (point.y - p1.y) - (point.x - p1.x) * (p2.y - p1.y);
      if (dist.abs() < tolerance) {
        if (point.x >= (p1.x < p2.x ? p1.x : p2.x) - tolerance &&
            point.x <= (p1.x > p2.x ? p1.x : p2.x) + tolerance &&
            point.y >= (p1.y < p2.y ? p1.y : p2.y) - tolerance &&
            point.y <= (p1.y > p2.y ? p1.y : p2.y) + tolerance) {
          return true; // Point is on the edge
        }
      }

      if (((p1.y > point.y) != (p2.y > point.y)) &&
          (point.x < (p2.x - p1.x) * (point.y - p1.y) / (p2.y - p1.y) + p1.x)) {
        isInside = !isInside;
      }
      j = i;
    }
    return isInside;
  }


}

