import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/models/notam_model.dart';
import 'package:brie_fly/models/temsi_chart_model.dart';
import 'package:brie_fly/models/wintem_chart_model.dart';
import 'package:brie_fly/services/notam_service.dart';
import 'package:brie_fly/services/navigation_service.dart';
import 'package:brie_fly/widgets/app_window_bar.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';

class NotamConfigScreen extends StatefulWidget {
  final List<String> selectedItems;
  final String airportCodes;
  final List<SelectedTemsiChart> selectedTemsiCharts;
  final List<SelectedWintemChart> selectedWintemCharts;

  const NotamConfigScreen({
    super.key,
    required this.selectedItems,
    required this.airportCodes,
    required this.selectedTemsiCharts,
    required this.selectedWintemCharts,
    this.flightPlanPath,
  });

  final String? flightPlanPath;


  @override
  _NotamConfigScreenState createState() => _NotamConfigScreenState();
}

class _NotamConfigScreenState extends State<NotamConfigScreen> {
  final NotamService _notamService = NotamService();
  final TextEditingController _searchController = TextEditingController();
  List<Notam> _allNotams = []; // Stores all results from the API
  final Set<Notam> _selectedNotams = {};
  bool _isLoading = false;
  String? _error;
  String _selectedIcaoFilter = 'All'; // The currently selected ICAO code for filtering
  List<String> _searchCodes = []; // The codes from the last search
  final TextEditingController _notamIdSearchController = TextEditingController();
  String _notamIdSearchQuery = '';
  bool _hasSearched = false;
  bool _isAllSelected = false;

  @override
  void dispose() {
    _searchController.dispose();
    _notamIdSearchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    // 1. Parse the input for multiple ICAO codes.
    final codes = _searchController.text
        .trim()
        .toUpperCase()
        .split(RegExp(r'[\s,]+'))
        .where((code) => code.isNotEmpty)
        .toSet() // Use a Set to avoid duplicate requests
        .toList();

    if (codes.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _allNotams = [];
      _hasSearched = true;
    });

    try {
      // 2. Perform parallel API calls for each ICAO code.
      final List<Future<List<Notam>>> futures = codes.map((code) => _notamService.fetchNotams(code)).toList();
      final List<List<Notam>> results = await Future.wait(futures);

      // 3. Aggregate the results into a single list.
      final List<Notam> allNotams = results.expand((notamList) => notamList).toList();

      setState(() {
        _allNotams = allNotams;
        _searchCodes = codes; // Store the searched codes
        _selectedIcaoFilter = 'All'; // Reset filter to 'All'
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch some NOTAMs: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleSelection(Notam notam) {
    setState(() {
      if (_selectedNotams.contains(notam)) {
        _selectedNotams.remove(notam);
      } else {
        _selectedNotams.add(notam);
      }
      _updateSelectAllState(); // Update the checkbox state
    });
  }

  // A helper getter to calculate the currently displayed NOTAMs based on filters.
  List<Notam> get _displayedNotams {
    List<Notam> notams = _selectedIcaoFilter == 'All'
        ? _allNotams
        : _allNotams.where((notam) => notam.icaoLocation == _selectedIcaoFilter).toList();

    if (_notamIdSearchQuery.isNotEmpty) {
      notams = notams.where((notam) {
        return notam.title.toLowerCase().contains(_notamIdSearchQuery.toLowerCase());
      }).toList();
    }
    return notams;
  }

  // Updates the state of the 'Select All' checkbox.
  void _updateSelectAllState() {
    final displayed = _displayedNotams;
    if (displayed.isEmpty) {
      _isAllSelected = false;
      return;
    }
    _isAllSelected = displayed.every((notam) => _selectedNotams.contains(notam));
  }

  // Toggles the selection of all currently displayed NOTAMs.
  void _toggleSelectAll(bool? value) {
    setState(() {
      _isAllSelected = value ?? false;
      if (_isAllSelected) {
        _selectedNotams.addAll(_displayedNotams);
      } else {
        _selectedNotams.removeAll(_displayedNotams);
      }
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
                            'NOTAMs',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 26, color: Colors.black87),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildSearchBar(),
                    _buildFilterAndSearchControls(),
                    _buildSelectedNotamsChips(),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                              ? Center(child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text('Error: $_error', style: const TextStyle(color: Colors.red, fontSize: 16)),
                              ))
                              : _allNotams.isEmpty
                                  ? Center(
                                      child: Text(
                                        _hasSearched ? 'No NOTAMs found for the requested area(s).' : 'Enter an ICAO code to search for NOTAMs.',
                                        style: GoogleFonts.montserrat(fontSize: 16),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  : _buildNotamList(),
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Enter ICAO Airport Code (e.g., KJFK)',
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
              onSubmitted: (_) => _performSearch(),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _performSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Search', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedNotamsChips() {
    if (_selectedNotams.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          // Limit height so it doesn't push content off-screen on phones
          maxHeight: 140,
        ),
        child: Scrollbar(
          thumbVisibility: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 8.0,
              runSpacing: 4.0,
              children: _selectedNotams.map((notam) {
                return Chip(
                  label: Text(notam.title, style: GoogleFonts.montserrat()),
                  onDeleted: () => _toggleSelection(notam),
                  backgroundColor: Colors.blue.shade100,
                  deleteIconColor: Colors.blue.shade700,
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotamList() {
    final displayedNotams = _displayedNotams;

    if (displayedNotams.isEmpty && _allNotams.isNotEmpty) {
      return Center(child: Text('No NOTAMs found for $_selectedIcaoFilter.', style: GoogleFonts.montserrat(fontSize: 16)));
    }

    return ListView.builder(
      itemCount: displayedNotams.length,
      itemBuilder: (context, index) {
        final notam = displayedNotams[index];
        final isSelected = _selectedNotams.contains(notam);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Checkbox(
              value: isSelected,
              onChanged: (bool? value) => _toggleSelection(notam),
              activeColor: const Color(0xFF1976D2),
            ),
            title: Text('${notam.icaoLocation} - ${notam.title}', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  notam.classification,
                  style: GoogleFonts.montserrat(color: Colors.blueGrey, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 8),
                Text(notam.body, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
            onTap: () => _showNotamPreview(context, notam),
          ),
        );
      },
    );
  }

  // Method to show a responsive, styled NOTAM preview dialog
  void _showNotamPreview(BuildContext context, Notam notam) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          elevation: 8.0,
          backgroundColor: Colors.white,
          title: Text(
            notam.title,
            style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          content: SizedBox(
            width: double.maxFinite, // Make dialog responsive
            child: SingleChildScrollView(
              child: Text(
                notam.body,
                style: GoogleFonts.lato(
                  fontSize: 16,
                  color: Colors.black.withOpacity(0.7),
                  height: 1.5,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'CLOSE',
                style: GoogleFonts.lato(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterAndSearchControls() {
    if (_allNotams.isEmpty) return const SizedBox.shrink();

    // Update the 'Select All' checkbox state whenever filters change.
    WidgetsBinding.instance.addPostFrameCallback((_) => setState(_updateSelectAllState));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          if (_searchCodes.length > 1)
            Flexible(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedIcaoFilter,
                    isExpanded: true,
                    icon: const Icon(Icons.filter_list, color: Colors.black87),
                    style: GoogleFonts.montserrat(color: Colors.black87),
                    dropdownColor: Colors.white,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedIcaoFilter = newValue!;
                      });
                    },
                    items: ['All', ..._searchCodes].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: GoogleFonts.montserrat(color: Colors.black87), overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          if (_searchCodes.length > 1) const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: TextField(
              controller: _notamIdSearchController,
              style: GoogleFonts.montserrat(),
              decoration: InputDecoration(
                hintText: 'Search by NOTAM ID...',
                hintStyle: GoogleFonts.montserrat(color: Colors.grey.shade600),
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: Color(0xFF1976D2), width: 1.5),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _notamIdSearchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          // 'Select All' Checkbox
          Row(
            children: [
              Checkbox(
                value: _isAllSelected,
                onChanged: _toggleSelectAll,
                activeColor: const Color(0xFF1976D2),
              ),
              Text('All', style: GoogleFonts.montserrat()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    bool isLast = NavigationService.isLastScreen('NOTAMs', widget.selectedItems);

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
              onPressed: () {
                final route = NavigationService.getNextScreenRoute(
                  context: context,
                  currentScreen: 'NOTAMs',
                  selectedItems: widget.selectedItems,
                  airportCodes: widget.airportCodes,
                  flightPlanPath: widget.flightPlanPath,
                  selectedTemsiCharts: widget.selectedTemsiCharts,
                  selectedWintemCharts: widget.selectedWintemCharts,
                  notams: _selectedNotams.toList(),
                );
                if (route != null) {
                  Navigator.push(context, route);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isLast ? 'Generate Dossier' : 'Continue',
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

