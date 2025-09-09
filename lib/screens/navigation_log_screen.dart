import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/models/flight_info_model.dart';
import 'package:brie_fly/models/nav_log_entry.dart';
import 'package:brie_fly/models/notam_model.dart';
import 'package:brie_fly/models/temsi_chart_model.dart';
import 'package:brie_fly/models/wintem_chart_model.dart';
import 'package:brie_fly/services/navigation_service.dart';
import 'package:brie_fly/widgets/app_window_bar.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';

class NavigationLogScreen extends StatefulWidget {
  final List<String> selectedItems;
  final String airportCodes;
  final List<SelectedTemsiChart> selectedTemsiCharts;
  final List<SelectedWintemChart> selectedWintemCharts;
  final List<Notam> selectedNotams;
  final String? flightPlanPath;

  const NavigationLogScreen({
    Key? key,
    required this.selectedItems,
    required this.airportCodes,
    required this.selectedTemsiCharts,
    required this.selectedWintemCharts,
    required this.selectedNotams,
    this.flightPlanPath,
  }) : super(key: key);

  @override
  State<NavigationLogScreen> createState() => _NavigationLogScreenState();
}

class _NavigationLogScreenState extends State<NavigationLogScreen> {
  final FlightInfo _flightInfo = FlightInfo();
  final List<NavLogEntry> _navLogEntries = List.generate(3, (_) => NavLogEntry());

  // Define the widths for the columns
  static const double _crewWidth = 130.0;
  static const double _standardColWidth = 120.0;
  final double _totalWidth = 1080.0;

  @override
  void initState() {
    super.initState();
    // Initialize with default values or load from a service
    _flightInfo.crew = 'Pilot Name';
    _flightInfo.aircraft = 'G-ABCD';
    _flightInfo.date = '2025-07-31';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.macOS);
    final bool isMobile = !isDesktop && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    final double bottomSafe = MediaQuery.of(context).padding.bottom;
    // Reserve more space at bottom to avoid overlap with FAB/system nav
    final double bottomReserve = (isMobile ? 240.0 : 96.0) + bottomSafe;
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        iconTheme: const IconThemeData(color: Colors.black87),
        textTheme: GoogleFonts.montserratTextTheme(ThemeData.light().textTheme)
            .apply(bodyColor: Colors.black87, displayColor: Colors.black87),
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
                padding: EdgeInsets.fromLTRB(
                  8.0,
                  8.0 + (isDesktop ? AppWindowBar.height : 0),
                  8.0,
                  bottomReserve,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: Text(
                              'Log de Navigation',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 56, letterSpacing: 0.5, color: Colors.black87),
                            ),
                          ),
                          if (isMobile)
                            IconButton(
                              icon: const Icon(Icons.arrow_forward),
                              onPressed: () {
                                final route = NavigationService.getNextScreenRoute(
                                  context: context,
                                  currentScreen: 'Navigation LOG',
                                  selectedItems: widget.selectedItems,
                                  airportCodes: widget.airportCodes,
                                  selectedTemsiCharts: widget.selectedTemsiCharts,
                                  selectedWintemCharts: widget.selectedWintemCharts,
                                  selectedNotams: widget.selectedNotams,
                                  flightPlanPath: widget.flightPlanPath,
                                );
                                if (route != null) {
                                  Navigator.of(context).push(route);
                                }
                              },
                            )
                          else
                            const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, bottomReserve),
                            child: SizedBox(
                              width: _totalWidth,
                              child: Column(
                                children: [
                                  _buildTurningPointChecklist(),
                                  _buildFlightInfoSection(),
                                  const SizedBox(height: 8),
                                  _buildNavLogTable(),
                                  SizedBox(height: bottomReserve),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: isMobile
            ? null
            : Padding(
                padding: EdgeInsets.only(bottom: 32.0 + bottomSafe),
                child: FloatingActionButton(
                  onPressed: () {
                    final route = NavigationService.getNextScreenRoute(
                      context: context,
                      currentScreen: 'Navigation LOG',
                      selectedItems: widget.selectedItems,
                      airportCodes: widget.airportCodes,
                      selectedTemsiCharts: widget.selectedTemsiCharts,
                      selectedWintemCharts: widget.selectedWintemCharts,
                      selectedNotams: widget.selectedNotams,
                      flightPlanPath: widget.flightPlanPath,
                    );
                    if (route != null) {
                      Navigator.of(context).push(route);
                    }
                  },
                  child: const Icon(Icons.arrow_forward),
                ),
              ),
      ),
    );
  }

  Widget _buildFlightInfoSection() {
    const double rowHeight = 40.0;

    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CREW CELL - Spans 3 rows
          Container(
            width: _crewWidth,
            height: rowHeight * 3,
            decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade400))),
            padding: const EdgeInsets.all(4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CREW:', style: GoogleFonts.robotoMono(fontWeight: FontWeight.bold, fontSize: 11)),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildEditableCell(
                    _flightInfo.crew,
                    (val) => setState(() => _flightInfo.crew = val),
                    expand: true,
                  ),
                ),
              ],
            ),
          ),

          // OTHER CELLS
          SizedBox(
            width: _totalWidth - _crewWidth - _standardColWidth, // Adjusted width
            child: Column(
              children: [
                // ROW 1
                Container(
                  height: rowHeight,
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade400))),
                  child: Row(
                    children: [
                      SizedBox(width: _standardColWidth, child: _buildInfoCellWithLabel('AIRCRAFT:', _flightInfo.aircraft, (val) => setState(() => _flightInfo.aircraft = val))),
                      SizedBox(width: _standardColWidth, child: _buildEditableCell(_flightInfo.cnpl, (val) => setState(() => _flightInfo.cnpl = val))),
                      SizedBox(width: _standardColWidth, child: _buildInfoCellWithLabel('TTSD:', _flightInfo.ttsd, (val) => setState(() => _flightInfo.ttsd = val))),
                      SizedBox(width: _standardColWidth, child: _buildCenteredStaticCell('HRS')),
                      SizedBox(width: _standardColWidth, child: _buildInfoCellWithLabel('TTSA:', _flightInfo.ttsa, (val) => setState(() => _flightInfo.ttsa = val))),
                      SizedBox(width: _standardColWidth, child: _buildCenteredStaticCell('HRS')),
                    ],
                  ),
                ),
                // ROW 2
                Container(
                  height: rowHeight,
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade400))),
                  child: Row(
                    children: [
                      SizedBox(width: _standardColWidth * 2, child: _buildInfoCellWithLabel('DATE:', _flightInfo.date, (val) => setState(() => _flightInfo.date = val))),
                      SizedBox(width: _standardColWidth, child: _buildInfoCellWithLabel('OFF:', _flightInfo.off, (val) => setState(() => _flightInfo.off = val))),
                      SizedBox(width: _standardColWidth, child: _buildTimeCell(_flightInfo.offZ, (val) => setState(() => _flightInfo.offZ = val), 'Z')),
                      SizedBox(width: _standardColWidth, child: _buildInfoCellWithLabel('ON:', _flightInfo.on, (val) => setState(() => _flightInfo.on = val))),
                      SizedBox(width: _standardColWidth, child: _buildTimeCell(_flightInfo.onZ, (val) => setState(() => _flightInfo.onZ = val), 'Z')),
                    ],
                  ),
                ),
                // ROW 3
                Container(
                  height: rowHeight,
                  child: Row(
                    children: [
                      SizedBox(width: _standardColWidth * 2, child: _buildInfoCellWithLabel('FUEL ON BOARD:', _flightInfo.fuelOnBoard, (val) => setState(() => _flightInfo.fuelOnBoard = val))),
                      SizedBox(width: _standardColWidth, child: _buildInfoCellWithLabel('T/O:', _flightInfo.tio, (val) => setState(() => _flightInfo.tio = val))),
                      SizedBox(width: _standardColWidth, child: _buildTimeCell(_flightInfo.tioZ, (val) => setState(() => _flightInfo.tioZ = val), 'Z')),
                      SizedBox(width: _standardColWidth, child: _buildInfoCellWithLabel('LDG:', _flightInfo.ldg, (val) => setState(() => _flightInfo.ldg = val))),
                      SizedBox(width: _standardColWidth, child: _buildTimeCell(_flightInfo.ldgZ, (val) => setState(() => _flightInfo.ldgZ = val), 'Z')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildFlCell(rowHeight * 3)),
        ],
      ),
    );
  }

  Widget _buildInfoCellWithLabel(
    String label, String initialValue, Function(String) onSave) {
    return Container(
      decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade400))),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(label, style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _buildEditableCell(initialValue, onSave),
          ),
        ],
      ),
    );
  }

  Widget _buildFlCell(double height) {
    return Container(
      height: height,
      width: _standardColWidth,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey.shade400)),
      ),
      child: Center(
        child: _buildInfoCellWithLabel(
          'FL:',
          _flightInfo.fl,
          (val) => setState(() => _flightInfo.fl = val),
        ),
      ),
    );
  }

  Widget _buildTurningPointChecklist() {
    return Container(
      width: _totalWidth,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        color: Colors.grey.shade200,
      ),
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'C/L Point tournant : ',
                  style: TextStyle(decoration: TextDecoration.underline),
                ),
                const TextSpan(
                  text: 'TOP CHRONO / CHRONO MARCHE   CAP/VALIDATION   ALT SEC',
                ),
              ],
            ),
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'ESTIMES(ETA/ATA)   RADIO   ENGINE   FUEL/FUEL XFER   RADIONAV',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCell(String initialValue, Function(String) onSave, String label) {
    return Container(
      decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade400))),
      child: Row(
        children: [
          Expanded(
            child: _buildEditableCell(initialValue, onSave),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(label, style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCenteredStaticCell(String text) {
    return Container(
      decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade400))),
      alignment: Alignment.center,
      child: Text(
        text,
        style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildNavLogTable() {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade400),
      columnWidths: const {
        0: FixedColumnWidth(180.0),
        1: FixedColumnWidth(120.0),
        2: FixedColumnWidth(90.0),
        3: FixedColumnWidth(90.0),
        4: FixedColumnWidth(90.0),
        5: FixedColumnWidth(120.0),
        6: FixedColumnWidth(150.0),
        7: FixedColumnWidth(150.0),
        8: FixedColumnWidth(90.0),
      },
      children: [
        _buildNavLogHeader(),
        ..._navLogEntries.map((entry) => _buildNavLogRow(entry)).toList(),
      ],
    );
  }

  TableRow _buildNavLogHeader() {
    const double totalHeaderHeight = 60;
    const double subHeaderHeight = totalHeaderHeight / 3;

    Widget buildSubHeader(String text) {
      return _buildHeaderCell(text, height: subHeaderHeight);
    }

    return TableRow(
      children: [
        _buildHeaderCell('WAYPOINT\nLAT/LONG', height: totalHeaderHeight),
        Column(children: [
          _buildHeaderCell('VOR', height: subHeaderHeight),
          Row(children: [Expanded(child: buildSubHeader('RAD')), Expanded(child: buildSubHeader('DIST'))]),
          SizedBox(height: subHeaderHeight), // Placeholder for 3rd line
        ]),
        Column(children: [
          _buildHeaderCell('FREQ', height: subHeaderHeight),
          _buildHeaderCell('DTK', height: subHeaderHeight),
          SizedBox(height: subHeaderHeight), // Placeholder for 3rd line
        ]),
        _buildHeaderCell('DTK', height: totalHeaderHeight),
        _buildHeaderCell('SAFE\nALT', height: totalHeaderHeight),
        Column(children: [
          _buildHeaderCell('DIST', height: subHeaderHeight),
          Row(children: [Expanded(child: buildSubHeader('LEG')), Expanded(child: buildSubHeader('REM'))]),
          SizedBox(height: subHeaderHeight), // Placeholder for 3rd line
        ]),
        Column(children: [
          _buildHeaderCell('TIMING', height: subHeaderHeight),
          Row(children: [Expanded(child: buildSubHeader('ETE')), Expanded(child: buildSubHeader('ETA'))]),
          Row(children: [Expanded(child: buildSubHeader('ATE')), Expanded(child: buildSubHeader('ATA'))]),
        ]),
        Column(children: [
          _buildHeaderCell('FUEL', height: subHeaderHeight),
          Row(children: [Expanded(child: buildSubHeader('CONS.')), Expanded(child: buildSubHeader('CUMUL'))]),
          SizedBox(height: subHeaderHeight), // Placeholder for 3rd line
        ]),
        _buildHeaderCell('ATS', height: totalHeaderHeight),
      ],
    );
  }

  TableRow _buildNavLogRow(NavLogEntry entry) {
    const double totalRowHeight = 60;
    const double cellHeight = totalRowHeight / 3;

    Widget buildCell(String value, Function(String) onSave) {
      return SizedBox(height: cellHeight, child: _buildEditableCell(value, onSave));
    }

    Widget buildDoubleCell(String val1, Function(String) onSave1, String val2, Function(String) onSave2) {
        return Column(children: [buildCell(val1, (v) => setState(() => onSave1(v))), buildCell(val2, (v) => setState(() => onSave2(v))), SizedBox(height: cellHeight)]);
    }

    return TableRow(
      children: [
        // WAYPOINT & LAT/LONG
        buildDoubleCell(entry.waypoint, (v) => entry.waypoint = v, entry.latLong, (v) => entry.latLong = v),
        // VOR (RAD/DIST)
        buildDoubleCell(entry.vorRad, (v) => entry.vorRad = v, entry.vorDist, (v) => entry.vorDist = v),
        // FREQ & DTK
        buildDoubleCell(entry.freq, (v) => entry.freq = v, entry.dtk, (v) => entry.dtk = v),
        // DTK
        SizedBox(height: totalRowHeight, child: _buildEditableCell(entry.dtk, (val) => setState(() => entry.dtk = val))),
        // SAFE ALT
        SizedBox(height: totalRowHeight, child: _buildEditableCell(entry.safeAlt, (val) => setState(() => entry.safeAlt = val))),
        // DIST (LEG/REM)
        buildDoubleCell(entry.distLeg, (v) => entry.distLeg = v, entry.distRem, (v) => entry.distRem = v),
        // TIMING (ETE/ETA, ATE/ATA)
        Column(children: [
          Row(children: [
            Expanded(child: buildCell(entry.timingEte, (v) => setState(() => entry.timingEte = v))),
            Expanded(child: buildCell(entry.timingEta, (v) => setState(() => entry.timingEta = v))),
          ]),
          Row(children: [
            Expanded(child: buildCell(entry.timingAte, (v) => setState(() => entry.timingAte = v))),
            Expanded(child: buildCell(entry.timingAta, (v) => setState(() => entry.timingAta = v))),
          ]),
          SizedBox(height: cellHeight),
        ]),
        // FUEL (CONS/CUMUL)
        buildDoubleCell(entry.fuelCons, (v) => entry.fuelCons = v, entry.fuelCumul, (v) => entry.fuelCumul = v),
        // ATS
        SizedBox(height: totalRowHeight, child: _buildEditableCell(entry.ats, (val) => setState(() => entry.ats = val))),
      ],
    );
  }

  Widget _buildHeaderCell(String text, {double height = 20}) {
    return Container(
      height: height,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Text(text, style: GoogleFonts.robotoMono(fontWeight: FontWeight.bold, fontSize: 10), textAlign: TextAlign.center),
    );
  }

  Widget _buildEditableCell(String initialValue, Function(String) onSave, {bool expand = false}) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: onSave,
      style: GoogleFonts.robotoMono(fontSize: 12),
      textAlign: TextAlign.center,
      maxLines: expand ? null : 1,
      minLines: expand ? null : 1,
      expands: expand,
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 4.0),
      ),
    );
  }


}

