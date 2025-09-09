import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:brie_fly/widgets/ad_pdf_viewer.dart';

class PdfViewerScreen extends StatefulWidget {
  final Uint8List? pdfBytes;
  final String? url;
  final String title;

  const PdfViewerScreen({Key? key, this.pdfBytes, this.url, required this.title}) : super(key: key);

  @override
  _PdfViewerScreenState createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final _controller = PdfViewerController();
  late final _textSearcher = PdfTextSearcher(_controller)..addListener(_update);
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final ValueNotifier<bool> _isSearchVisibleNotifier = ValueNotifier(false);
  int _currentMatchDisplayIndex = 0;
  int _currentPage = 1;
  int _pageCount = 0;
  bool _showPageIndicator = false;
  Timer? _hideIndicatorTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  void _update() {
    if (mounted) {
      // Sync display index with searcher's current index when available
      if (_textSearcher.currentIndex != null) {
        _currentMatchDisplayIndex = _textSearcher.currentIndex!.clamp(0, (_textSearcher.matches.length - 1).clamp(0, 1 << 30));
      } else if (_textSearcher.matches.isNotEmpty) {
        // When results become available but no current index is selected, show the first (1/N) without jumping
        _currentMatchDisplayIndex = 0;
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _textSearcher.removeListener(_update);
    _textSearcher.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _isSearchVisibleNotifier.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    // Update page info when controller changes (scroll/zoom/page switch)
    final newPage = _controller.pageNumber ?? _currentPage;
    final newCount = _controller.pageCount ?? _pageCount;
    if (newPage != _currentPage || newCount != _pageCount) {
      setState(() {
        _currentPage = newPage;
        _pageCount = newCount;
      });
    }
    _showTransientPageIndicator();
  }

  void _showTransientPageIndicator() {
    // Show indicator now and schedule hide
    _hideIndicatorTimer?.cancel();
    if (!_showPageIndicator) {
      setState(() {
        _showPageIndicator = true;
      });
    }
    _hideIndicatorTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _showPageIndicator = false;
      });
    });
  }

  void _startSearch(String text) {
    if (text.isNotEmpty) {
      // Preserve current viewport to avoid any jump due to internal layout
      final currentCenter = _controller.visibleRect.center;
      final currentZoom = _controller.currentZoom;

      // Use pdfrx's option to prevent jumping to the first match
      _textSearcher.startTextSearch(
        text.toLowerCase(),
        goToFirstMatch: false,
        searchImmediately: true,
      );

      // Restore viewport on next frame to ensure we stay on the same page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.setZoom(currentCenter, currentZoom);
      });
      // Also restore after a short delay in case internal async scroll occurs
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        _controller.setZoom(currentCenter, currentZoom);
      });

      // Reset display index on new search
      _currentMatchDisplayIndex = _textSearcher.currentIndex ?? 0;
    } else {
      _textSearcher.resetTextSearch();
      _currentMatchDisplayIndex = 0;
    }
  }

  void _clearSearch() {
    _textSearcher.resetTextSearch();
    _searchController.clear();
    _currentMatchDisplayIndex = 0;
  }

  void _toggleSearch() {
    _isSearchVisibleNotifier.value = !_isSearchVisibleNotifier.value;
    if (_isSearchVisibleNotifier.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocusNode.requestFocus());
    } else {
      _clearSearch();
      _searchFocusNode.unfocus();
    }
  }

  Widget _buildViewer() {
    if (widget.url != null && widget.url!.isNotEmpty) {
      return AdPdfViewer.uri(
        Uri.parse(widget.url!),
        controller: _controller,
        params: PdfViewerParams(
          pagePaintCallbacks: [_textSearcher.pageTextMatchPaintCallback],
          // Suppress default error banner; rely on spinner and viewer state
          errorBannerBuilder: (context, error, stackTrace, docRef) => const SizedBox.shrink(),
        ),
      );
    }
    if (widget.pdfBytes != null) {
      return AdPdfViewer.data(
        widget.pdfBytes!,
        sourceName: 'document.pdf',
        controller: _controller,
        params: PdfViewerParams(
          pagePaintCallbacks: [_textSearcher.pageTextMatchPaintCallback],
          errorBannerBuilder: (context, error, stackTrace, docRef) => const SizedBox.shrink(),
        ),
      );
    }
    return const Text('No PDF source provided');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isSearchVisibleNotifier,
      builder: (context, isSearchVisible, child) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.grey.shade900,
            foregroundColor: Colors.white,
            title: isSearchVisible
                ? TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: false,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Search...',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (value) {
                      _startSearch(value);
                    },
                  )
                : Text(widget.title, style: const TextStyle(fontSize: 16)),
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.zoom_in),
                onPressed: () {
                  _controller.setZoom(_controller.visibleRect.center, _controller.currentZoom * 1.2);
                },
              ),
              IconButton(
                icon: const Icon(Icons.zoom_out),
                onPressed: () {
                  if (_controller.currentZoom > 0.5) {
                    _controller.setZoom(_controller.visibleRect.center, _controller.currentZoom / 1.2);
                  }
                },
              ),
              IconButton(
                icon: Icon(isSearchVisible ? Icons.clear : Icons.search),
                onPressed: _toggleSearch,
              ),
              if (isSearchVisible && _textSearcher.matches.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: () {
                        if (_textSearcher.matches.isNotEmpty) {
                          _textSearcher.goToPrevMatch();
                          // Update local display index
                          setState(() {
                            _currentMatchDisplayIndex =
                                (_currentMatchDisplayIndex - 1 + _textSearcher.matches.length) % _textSearcher.matches.length;
                          });
                        }
                      },
                    ),
                    Text(
                      _textSearcher.matches.isEmpty
                          ? '0 / 0'
                          : '${_currentMatchDisplayIndex + 1} / ${_textSearcher.matches.length}',
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward),
                      onPressed: () {
                        if (_textSearcher.matches.isNotEmpty) {
                          _textSearcher.goToNextMatch();
                          // Update local display index
                          setState(() {
                            _currentMatchDisplayIndex =
                                (_currentMatchDisplayIndex + 1) % _textSearcher.matches.length;
                          });
                        }
                      },
                    ),
                  ],
                ),
            ],
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: _buildViewer(),
                ),
              ),
              // Loading overlay while document is initializing/first pages are not ready
              if (_pageCount <= 0)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              // Transient page indicator on the right
              Positioned(
                right: 12,
                top: MediaQuery.of(context).size.height * 0.3,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _showPageIndicator ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: _pageCount <= 0
                        ? const SizedBox.shrink()
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              '$_currentPage / $_pageCount',
                              style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


