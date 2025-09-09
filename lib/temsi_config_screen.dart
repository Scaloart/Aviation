import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_view/photo_view.dart';
import 'package:brie_fly/services/navigation_service.dart';
import '../models/temsi_chart_model.dart';
import '../services/temsi_data_service.dart';
import 'package:brie_fly/models/notam_model.dart';
import 'package:brie_fly/widgets/app_window_bar.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';

class TemsiConfigScreen extends StatefulWidget {
  final List<String> selectedItems;
  final String airportCodes;

  const TemsiConfigScreen({
    super.key,
    required this.selectedItems,
    required this.airportCodes,
    this.flightPlanPath,
    this.notams = const [],
  });

  final String? flightPlanPath;
  final List<Notam> notams;

  @override
  _TemsiConfigScreenState createState() => _TemsiConfigScreenState();
}

class _TemsiConfigScreenState extends State<TemsiConfigScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TemsiDataService _dataService = TemsiDataService();
  final Set<SelectedTemsiChart> _selectedCharts = {};

  TemsiChartRegion? _selectedEnRouteRegion;
  TemsiChartRegion? _selectedBassesCouchesRegion;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleChartSelection(TemsiChartRegion region, TemsiChartTime time) {
    final selection = SelectedTemsiChart(
      region: region.region,
      timeLabel: time.label,
      imageUrl: time.imageUrl,
    );
    setState(() {
      if (_selectedCharts.contains(selection)) {
        _selectedCharts.remove(selection);
      } else {
        _selectedCharts.add(selection);
      }
    });
  }

  void _removeChartSelection(SelectedTemsiChart selection) {
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
                            'Carte TEMSI',
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
                        Tab(text: 'TEMSI En Route'),
                        Tab(text: 'TEMSI Basses Couches'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildSelectedChartsChips(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildChartSelectionTab(
                            regions: _dataService.getEnRouteCharts(),
                            hasSlider: true,
                            selectedRegion: _selectedEnRouteRegion,
                            onRegionChanged: (region) {
                              setState(() {
                                _selectedEnRouteRegion = region;
                              });
                            },
                          ),
                          _buildChartSelectionTab(
                            regions: _dataService.getBassesCouchesCharts(),
                            hasSlider: true,
                            selectedRegion: _selectedBassesCouchesRegion,
                            onRegionChanged: (region) {
                              setState(() {
                                _selectedBassesCouchesRegion = region;
                              });
                            },
                          ),
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
            label: Text('${chart.region} (${chart.timeLabel})'),
            onDeleted: () => _removeChartSelection(chart),
            backgroundColor: Colors.blue.shade100,
            deleteIconColor: Colors.blue.shade700,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChartSelectionTab({
    required List<TemsiChartRegion> regions,
    required bool hasSlider,
    required TemsiChartRegion? selectedRegion,
    required ValueChanged<TemsiChartRegion?> onRegionChanged,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          DropdownButtonFormField<TemsiChartRegion>(
            value: selectedRegion,
            hint: const Text('Select a Region'),
            isExpanded: true,
            style: GoogleFonts.montserrat(color: Colors.black87),
            iconEnabledColor: Colors.black87,
            iconDisabledColor: Colors.black45,
            items: regions.map((region) {
              return DropdownMenuItem(
                value: region,
                child: Text(
                  region.region,
                  style: GoogleFonts.montserrat(color: Colors.black87),
                ),
              );
            }).toList(),
            onChanged: onRegionChanged,
            dropdownColor: Colors.white,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1976D2), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),
          if (selectedRegion != null)
            TemsiRegionCard(
              key: ValueKey(selectedRegion.region), // Ensures widget rebuilds on region change
              region: selectedRegion,
              hasSlider: hasSlider,
              selectedCharts: _selectedCharts,
              onToggleSelection: _toggleChartSelection,
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    bool isLast = NavigationService.isLastScreen('Carte TEMSI', widget.selectedItems);
    return Padding(
      padding: const EdgeInsets.all(16.0),
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
                        currentScreen: 'Carte TEMSI',
                        selectedItems: widget.selectedItems,
                        airportCodes: widget.airportCodes,
                        flightPlanPath: widget.flightPlanPath,
                        selectedTemsiCharts: _selectedCharts.toList(),
                        selectedWintemCharts: const [], // Placeholder
                        notams: widget.notams,
                      );
                      if (route != null) {
                        Navigator.push(context, route);
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                disabledBackgroundColor: Colors.grey.shade400,
              ),
              child: Text(
                isLast ? 'Generate Dossier' : 'Continue',
                style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TemsiRegionCard extends StatefulWidget {
  final TemsiChartRegion region;
  final bool hasSlider;
  final Set<SelectedTemsiChart> selectedCharts;
  final Function(TemsiChartRegion, TemsiChartTime) onToggleSelection;

  const TemsiRegionCard({
    super.key,
    required this.region,
    required this.hasSlider,
    required this.selectedCharts,
    required this.onToggleSelection,
  });

  @override
  _TemsiRegionCardState createState() => _TemsiRegionCardState();
}

class _TemsiRegionCardState extends State<TemsiRegionCard> {
  late int _currentTimeIndex;

  @override
  void initState() {
    super.initState();
    _currentTimeIndex = 0;
  }

  TemsiChartTime get _currentTime => widget.region.times[_currentTimeIndex];

  void _navigateTime(int direction) {
    setState(() {
      _currentTimeIndex = (_currentTimeIndex + direction).clamp(0, widget.region.times.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.selectedCharts.contains(SelectedTemsiChart(
        region: widget.region.region,
        timeLabel: _currentTime.label,
        imageUrl: _currentTime.imageUrl));

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.region.region, style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (widget.hasSlider)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _buildTimelineSelector(),
              )
            else
              Text('Time: ${_currentTime.label}', style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FullScreenImageViewer(imageUrl: _currentTime.imageUrl),
                  ),
                );
              },
              child: Hero(
                tag: _currentTime.imageUrl,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      _currentTime.imageUrl,
                      fit: BoxFit.fitWidth,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 48),
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
                widget.onToggleSelection(widget.region, _currentTime);
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
              children: List.generate(widget.region.times.length, (index) {
                final time = widget.region.times[index];
                final isSelected = _currentTimeIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: GestureDetector(
                    onTap: () => setState(() => _currentTimeIndex = index),
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
          onPressed: _currentTimeIndex < widget.region.times.length - 1 ? () => _navigateTime(1) : null,
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

