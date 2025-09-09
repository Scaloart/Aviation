import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_view/photo_view.dart';
import 'package:brie_fly/models/temsi_chart_model.dart';
import 'package:brie_fly/services/navigation_service.dart';
import '../models/wintem_chart_model.dart';
import '../services/wintem_data_service.dart';
import 'package:brie_fly/models/notam_model.dart';
import 'package:brie_fly/widgets/app_window_bar.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';

class WintemConfigScreen extends StatefulWidget {
  final List<String> selectedItems;
  final String airportCodes;
  final List<SelectedTemsiChart>? selectedTemsiCharts;
  final String? flightPlanPath;
  final List<Notam> notams;

  const WintemConfigScreen({
    super.key,
    required this.selectedItems,
    required this.airportCodes,
    this.selectedTemsiCharts,
    this.flightPlanPath,
    this.notams = const [],
  });

  @override
  _WintemConfigScreenState createState() => _WintemConfigScreenState();
}

class _WintemConfigScreenState extends State<WintemConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final WintemDataService _dataService = WintemDataService();
  final Set<SelectedWintemChart> _selectedCharts = {};

  List<WintemArea> _enRouteCharts = [];
  List<WintemArea> _marocCharts = [];

  WintemArea? _selectedArea;
  WintemFlightLevel? _selectedEnRouteFlightLevel;
  WintemFlightLevel? _selectedMarocFlightLevel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadChartData();
  }

  void _loadChartData() {
    setState(() {
      _enRouteCharts = _dataService.getEnRouteCharts();
      _marocCharts = _dataService.getMarocCharts();

      if (_marocCharts.isNotEmpty && _marocCharts.first.flightLevels.isNotEmpty) {
        _selectedMarocFlightLevel = _marocCharts.first.flightLevels.first;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleChartSelection(
      WintemArea? area, WintemFlightLevel flightLevel, WintemChartTime time) {
    final selection = SelectedWintemChart(
      area: area?.area,
      flightLevel: flightLevel.level,
      timeLabel: time.label,
      imageUrl: time.imageUrl,
    );
    setState(() {
      if (_selectedCharts.any((c) =>
          c.area == selection.area &&
          c.flightLevel == selection.flightLevel &&
          c.timeLabel == selection.timeLabel)) {
        _selectedCharts.removeWhere((c) =>
            c.area == selection.area &&
            c.flightLevel == selection.flightLevel &&
            c.timeLabel == selection.timeLabel);
      } else {
        _selectedCharts.add(selection);
      }
    });
  }

  void _removeChartSelection(SelectedWintemChart selection) {
    setState(() {
      _selectedCharts.remove(selection);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.macOS);
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        iconTheme: const IconThemeData(color: Colors.black87),
        textTheme: GoogleFonts.montserratTextTheme(ThemeData.light().textTheme)
            .apply(bodyColor: Colors.black87, displayColor: Colors.black87),
        cardColor: Colors.white,
        popupMenuTheme: const PopupMenuThemeData(color: Colors.white),
        canvasColor: Colors.white,
        dialogBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          background: Color(0xFFF5F5F5),
          surface: Colors.white,
          primary: Color(0xFF1976D2),
          onPrimary: Colors.white,
          onSurface: Colors.black87,
        ),
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
                            'Carte WINTEM',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 26, color: Colors.black87),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TabBar(
                      controller: _tabController,
                      labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                      unselectedLabelStyle: GoogleFonts.montserrat(),
                      indicatorColor: const Color(0xFF1976D2),
                      indicatorWeight: 3,
                      tabs: const [
                        Tab(text: 'Wintem En Route'),
                        Tab(text: 'Wintem Maroc'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildSelectedChartsChips(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildEnRouteTab(),
                          _buildMarocTab(),
                        ],
                      ),
                    ),
                    _buildNavigationButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedChartsChips() {
    if (_selectedCharts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: 8.0,
        runSpacing: 4.0,
        children: _selectedCharts.map((chart) {
          return Chip(
            label: Text(
                '${chart.area ?? 'Maroc'} - ${chart.flightLevel} (${chart.timeLabel})'),
            onDeleted: () => _removeChartSelection(chart),
            backgroundColor: Colors.blue.shade100,
            deleteIconColor: Colors.blue.shade700,
            labelStyle: GoogleFonts.montserrat(color: Colors.blue.shade900),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEnRouteTab() {
    if (_enRouteCharts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          DropdownButtonFormField<WintemArea>(
            value: _selectedArea,
            hint: const Text('Select an Area'),
            isExpanded: true,
            style: GoogleFonts.montserrat(color: Colors.black87),
            iconEnabledColor: Colors.black87,
            iconDisabledColor: Colors.black45,
            items: _enRouteCharts.map((area) {
              return DropdownMenuItem(
                value: area,
                child: Text(
                  area.area,
                  style: GoogleFonts.montserrat(color: Colors.black87),
                ),
              );
            }).toList(),
            onChanged: (area) {
              setState(() {
                _selectedArea = area;
                _selectedEnRouteFlightLevel = null; // Reset flight level
              });
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: Color(0xFF1976D2), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            dropdownColor: Colors.white,
          ),
          const SizedBox(height: 20),
          if (_selectedArea != null)
            DropdownButtonFormField<WintemFlightLevel>(
              value: _selectedEnRouteFlightLevel,
              hint: const Text('Select a Flight Level'),
              isExpanded: true,
              style: GoogleFonts.montserrat(color: Colors.black87),
              iconEnabledColor: Colors.black87,
              iconDisabledColor: Colors.black45,
              items: _selectedArea!.flightLevels.map((fl) {
                return DropdownMenuItem(
                  value: fl,
                  child: Text(
                    fl.level,
                    style: GoogleFonts.montserrat(color: Colors.black87),
                  ),
                );
              }).toList(),
              onChanged: (fl) {
                setState(() {
                  _selectedEnRouteFlightLevel = fl;
                });
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Color(0xFF1976D2), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              dropdownColor: Colors.white,
            ),
          const SizedBox(height: 20),
          if (_selectedArea != null && _selectedEnRouteFlightLevel != null)
            WintemChartCard(
              key: ValueKey(
                  '${_selectedArea!.area}-${_selectedEnRouteFlightLevel!.level}'),
              area: _selectedArea,
              flightLevel: _selectedEnRouteFlightLevel!,
              selectedCharts: _selectedCharts,
              onToggleSelection: (fl, time) =>
                  _toggleChartSelection(_selectedArea, fl, time),
            ),
        ],
      ),
    );
  }

  Widget _buildMarocTab() {
    if (_marocCharts.isEmpty || _marocCharts.first.flightLevels.isEmpty) {
      return const Center(child: Text('No charts available.'));
    }

    final flightLevels = _marocCharts.first.flightLevels;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          DropdownButtonFormField<WintemFlightLevel>(
            value: _selectedMarocFlightLevel,
            hint: const Text('Select a Flight Level'),
            isExpanded: true,
            style: GoogleFonts.montserrat(color: Colors.black87),
            iconEnabledColor: Colors.black87,
            iconDisabledColor: Colors.black45,
            items: flightLevels.map((fl) {
              return DropdownMenuItem(
                value: fl,
                child: Text(
                  fl.level,
                  style: GoogleFonts.montserrat(color: Colors.black87),
                ),
              );
            }).toList(),
            onChanged: (fl) {
              setState(() {
                _selectedMarocFlightLevel = fl;
              });
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: Color(0xFF1976D2), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            dropdownColor: Colors.white,
          ),
          const SizedBox(height: 20),
          if (_selectedMarocFlightLevel != null)
            WintemChartCard(
              key: ValueKey('Maroc-${_selectedMarocFlightLevel!.level}'),
              flightLevel: _selectedMarocFlightLevel!,
              selectedCharts: _selectedCharts,
              onToggleSelection: (fl, time) =>
                  _toggleChartSelection(null, fl, time),
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    bool isLast = NavigationService.isLastScreen('Carte WINTEM', widget.selectedItems);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade300,
                minimumSize: const Size(double.infinity, 50),
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
              onPressed: _selectedCharts.isNotEmpty
                  ? () {
                      final route = NavigationService.getNextScreenRoute(
                        context: context,
                        currentScreen: 'Carte WINTEM',
                        selectedItems: widget.selectedItems,
                        airportCodes: widget.airportCodes,
                        flightPlanPath: widget.flightPlanPath,
                        selectedTemsiCharts: widget.selectedTemsiCharts ?? [],
                        selectedWintemCharts: _selectedCharts.toList(),
                        notams: widget.notams,
                      );
                      if (route != null) {
                        Navigator.push(context, route);
                      } else {
                        // Handle end of dossier
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedCharts.isNotEmpty
                    ? (isLast ? Colors.green : const Color(0xFF1976D2))
                    : Colors.grey,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isLast ? 'Terminer' : 'Continuer',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WintemChartCard extends StatefulWidget {
  final WintemArea? area;
  final WintemFlightLevel flightLevel;
  final Set<SelectedWintemChart> selectedCharts;
  final Function(WintemFlightLevel, WintemChartTime) onToggleSelection;

  const WintemChartCard({
    super.key,
    this.area,
    required this.flightLevel,
    required this.selectedCharts,
    required this.onToggleSelection,
  });

  @override
  _WintemChartCardState createState() => _WintemChartCardState();
}

class _WintemChartCardState extends State<WintemChartCard> {
  late WintemChartTime _currentTime;
  int _currentTimeIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentTime = widget.flightLevel.times.first;
  }

  @override
  void didUpdateWidget(covariant WintemChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flightLevel != oldWidget.flightLevel) {
      setState(() {
        _currentTimeIndex = 0;
        _currentTime = widget.flightLevel.times.first;
      });
    }
  }

  void _navigateTime(int direction) {
    setState(() {
      _currentTimeIndex = (_currentTimeIndex + direction)
          .clamp(0, widget.flightLevel.times.length - 1);
      _currentTime = widget.flightLevel.times[_currentTimeIndex];
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.selectedCharts
        .any((c) => c.imageUrl == _currentTime.imageUrl);
    final isDesktop = MediaQuery.of(context).size.width > 600;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _buildTimelineSelector(),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenImageViewer(imageUrl: _currentTime.imageUrl),
                ),
              ),
              child: Hero(
                tag: _currentTime.imageUrl,
                child: AspectRatio(
                  aspectRatio: isDesktop ? 16 / 9 : 4 / 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _currentTime.imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.error, size: 48),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: Text('Include in dossier', style: GoogleFonts.montserrat()),
              value: isSelected,
              onChanged: (bool? value) {
                widget.onToggleSelection(widget.flightLevel, _currentTime);
              },
              activeColor: const Color(0xFF1976D2),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: _currentTimeIndex > 0 ? () => _navigateTime(-1) : null,
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(widget.flightLevel.times.length, (index) {
                final time = widget.flightLevel.times[index];
                final isSelected = _currentTimeIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentTimeIndex = index;
                        _currentTime = widget.flightLevel.times[index];
                      });
                    },
                    child: Text(
                      time.label,
                      style: GoogleFonts.montserrat(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? const Color(0xFF1976D2) : Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: _currentTimeIndex < widget.flightLevel.times.length - 1
              ? () => _navigateTime(1)
              : null,
        ),
      ],
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: Colors.black,
        child: PhotoView(
          imageProvider: NetworkImage(imageUrl),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
          heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
        ),
      ),
    );
  }
}

