import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:brie_fly/screens/salahvideo.dart';

enum VideoType { network, youtube }

class Video {
  final String title;
  final String url;
  final VideoType videoType;
  final Map<String, String>? resolutions;

  Video({required this.title, required this.url, this.videoType = VideoType.network, this.resolutions});
}

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final List<Video> _allVideos = [
    Video(
      title: '1 GENERAL INFO',
      url: 'https://archive.org/download/3-performance/1%20GENERAL%20INFO.ia.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/3-performance/1%20GENERAL%20INFO.mp4',
        'Archive IA': 'https://archive.org/download/3-performance/1%20GENERAL%20INFO.ia.mp4',
      },
    ),
    Video(
      title: '2 OPERATING LIMITATIONS',
      url: 'https://archive.org/download/3-performance/2%20OPERATING%20LIMITATIONS.ia.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/3-performance/2%20OPERATING%20LIMITATIONS.mp4',
        'Archive IA': 'https://archive.org/download/3-performance/2%20OPERATING%20LIMITATIONS.ia.mp4',
      },
    ),
    Video(
      title: '3 PERFORMANCE',
      url: 'https://archive.org/download/3-performance/3%20PERFORMANCE.ia.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/3-performance/3%20PERFORMANCE.mp4',
        'Archive IA': 'https://archive.org/download/3-performance/3%20PERFORMANCE.ia.mp4',
      },
    ),
    Video(
      title: '4 MASS AND BALANCE',
      url: 'https://archive.org/download/3-performance/4%20MASS%20AND%20BALANCE.ia.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/3-performance/4%20MASS%20AND%20BALANCE.mp4',
        'Archive IA': 'https://archive.org/download/3-performance/4%20MASS%20AND%20BALANCE.ia.mp4',
      },
    ),
    Video(
      title: '5 AIRFRAME',
      url: 'https://archive.org/download/3-performance/5%20AIRFRAME.ia.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/3-performance/5%20AIRFRAME.mp4',
        'Archive IA': 'https://archive.org/download/3-performance/5%20AIRFRAME.ia.mp4',
      },
    ),
    Video(
      title: '6 FLIGHT CONTROLS',
      url: 'https://archive.org/download/3-performance/6%20FLIGHT%20CONTROLS.ia.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/3-performance/6%20FLIGHT%20CONTROLS.mp4',
        'Archive IA': 'https://archive.org/download/3-performance/6%20FLIGHT%20CONTROLS.ia.mp4',
      },
    ),
    Video(
      title: '7 INSTRUMENT PANEL',
      url: 'https://archive.org/download/3-performance/7%20INSTRUMENT%20PANEL.ia.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/3-performance/7%20INSTRUMENT%20PANEL.mp4',
        'Archive IA': 'https://archive.org/download/3-performance/7%20INSTRUMENT%20PANEL.ia.mp4',
      },
    ),
    Video(
      title: '8 LANDING GEAR',
      url: 'https://archive.org/download/3-performance/8%20LANDING%20GEAR.ia.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/3-performance/8%20LANDING%20GEAR.mp4',
        'Archive IA': 'https://archive.org/download/3-performance/8%20LANDING%20GEAR.ia.mp4',
      },
    ),
    Video(
      title: '9 SEATS AND SAFETY HARNESS',
      url: 'https://archive.org/download/3-performance/9%20SEATS%20AND%20SAFETY%20HARNESS.ia.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/3-performance/9%20SEATS%20AND%20SAFETY%20HARNESS.mp4',
        'Archive IA': 'https://archive.org/download/3-performance/9%20SEATS%20AND%20SAFETY%20HARNESS.ia.mp4',
      },
    ),
    Video(
      title: '10 BAGGAGE COMPARTMENT',
      url: 'https://archive.org/download/3-performance/10%20BAGGAGE%20COMPARTMENT.ia.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/3-performance/10%20BAGGAGE%20COMPARTMENT.mp4',
        'Archive IA': 'https://archive.org/download/3-performance/10%20BAGGAGE%20COMPARTMENT.ia.mp4',
      },
    ),
    Video(
      title: '11 CANOPY, REAR DOOR AND CABIN',
      url: 'https://archive.org/download/22-avionics-part-1/11%20CANOPY%2C%20REAR%20DOOR%20AND%20CABIN.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/22-avionics-part-1/11%20CANOPY%2C%20REAR%20DOOR%20AND%20CABIN.mp4',
      },
    ),
    Video(
      title: '12 POWER PLANT GENERAL INFORMATION',
      url: 'https://archive.org/download/22-avionics-part-1/12%20POWER%20PLANT%20GENERAL%20INFORMATION.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/22-avionics-part-1/12%20POWER%20PLANT%20GENERAL%20INFORMATION.mp4',
      },
    ),
    Video(
      title: '13 POWER PLANT OPERATING CONTROLS',
      url: 'https://archive.org/download/22-avionics-part-1/13%20POWER%20PLANT%20OPERATING%20CONTROLS.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/22-avionics-part-1/13%20POWER%20PLANT%20OPERATING%20CONTROLS.mp4',
      },
    ),
    Video(
      title: '14 POWER PLANT PROPELLER',
      url: 'https://archive.org/download/22-avionics-part-1/14%20POWER%20PLANT%20PROPELLER.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/22-avionics-part-1/14%20POWER%20PLANT%20PROPELLER.mp4',
      },
    ),
    Video(
      title: '15 POWER PLANT FUEL SYSTEM',
      url: 'https://archive.org/download/22-avionics-part-1/15%20POWER%20PLANT%20FUEL%20SYSTEM.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/22-avionics-part-1/15%20POWER%20PLANT%20FUEL%20SYSTEM.mp4',
      },
    ),
    Video(
      title: '16 POWER PLANT COOLING SYSTEM',
      url: 'https://archive.org/download/22-avionics-part-1/16%20POWER%20PLANT%20COOLING%20SYSTEM.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/22-avionics-part-1/16%20POWER%20PLANT%20COOLING%20SYSTEM.mp4',
      },
    ),
    Video(
      title: '17 POWER PLANT TURBO CHARGER SYSTEM',
      url: 'https://archive.org/download/22-avionics-part-1/17%20POWER%20PLANT%20TURBO%20CHARGER%20SYSTEM.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/22-avionics-part-1/17%20POWER%20PLANT%20TURBO%20CHARGER%20SYSTEM.mp4',
      },
    ),
    Video(
      title: '18 POWER PLANT OIL SYSTEM',
      url: 'https://archive.org/download/22-avionics-part-1/18%20POWER%20PLANT%20OIL%20SYSTEM.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/22-avionics-part-1/18%20POWER%20PLANT%20OIL%20SYSTEM.mp4',
      },
    ),
    Video(
      title: '19 ELECTRICAL SYSTEM',
      url: 'https://archive.org/download/22-avionics-part-1/19%20ELECTRICAL%20SYSTEM.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/22-avionics-part-1/19%20ELECTRICAL%20SYSTEM.mp4',
      },
    ),
    Video(
      title: '20 PITOT STATIC SYSTEM',
      url: 'https://archive.org/download/22-avionics-part-1/20%20PITOT%20STATIC%20SYSTEM.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/22-avionics-part-1/20%20PITOT%20STATIC%20SYSTEM.mp4',
      },
    ),
    Video(
      title: '21 STALL WARNING SYSTEM',
      url: 'https://archive.org/download/22-avionics-part-1/21%20STALL%20WARNING%20SYSTEM.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/22-avionics-part-1/21%20STALL%20WARNING%20SYSTEM.mp4',
      },
    ),
    Video(
      title: '22 AVIONICS PART 1',
      url: 'https://archive.org/download/22-avionics-part-1/22%20AVIONICS%20PART%201.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/22-avionics-part-1/22%20AVIONICS%20PART%201.mp4',
      },
    ),
    Video(
      title: '23 AVIONICS PART 2',
      url: 'https://archive.org/download/22-avionics-part-1/23%20AVIONICS%20PART%202.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/22-avionics-part-1/23%20AVIONICS%20PART%202.mp4',
      },
    ),
    Video(
      title: '24 AIRCRAFT HANDLING, CARE & MAINTENANCE',
      url: 'https://archive.org/download/22-avionics-part-1/24%20AIRCRAFT%20HANDLING%2C%20CARE%20%26%20MAINTENANCE.mp4',
      resolutions: {
        'Default': 'https://archive.org/download/22-avionics-part-1/24%20AIRCRAFT%20HANDLING%2C%20CARE%20%26%20MAINTENANCE.mp4',
      },
    ),
  ];

  List<Video> _filteredVideos = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _filteredVideos = _allVideos;
    _searchController.addListener(_filterVideos);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterVideos() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredVideos = _allVideos.where((video) {
        return video.title.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Build-time snapshot of current filtered list for navigation
    final playlistUrls = _filteredVideos.map((v) => v.url).toList(growable: false);
    final playlistTitles = _filteredVideos.map((v) => v.title).toList(growable: false);
    return BackgroundContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(color: Colors.white),
                )
              : Text('Playlist', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                  }
                });
              },
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final int columns = (constraints.maxWidth ~/ 200).clamp(2, 8);
            return GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                childAspectRatio: 160 / 220,
              ),
              itemCount: _filteredVideos.length,
              itemBuilder: (context, index) {
                final video = _filteredVideos[index];
                return VideoThumbnailItem(
                  video: video,
                  allUrls: playlistUrls,
                  allTitles: playlistTitles,
                  initialIndex: index,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class VideoThumbnailItem extends StatefulWidget {
  final Video video;
  final List<String> allUrls;
  final List<String> allTitles;
  final int initialIndex;

  const VideoThumbnailItem({Key? key, required this.video, required this.allUrls, required this.allTitles, required this.initialIndex}) : super(key: key);

  @override
  _VideoThumbnailItemState createState() => _VideoThumbnailItemState();
}

class _VideoThumbnailItemState extends State<VideoThumbnailItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(_isHovered ? 1.05 : 1.0),
        transformAlignment: Alignment.center,
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlayerShell(
                  videoUrl: widget.video.url,
                  videoTitle: widget.video.title,
                  playlistUrls: widget.allUrls,
                  playlistTitles: widget.allTitles,
                  initialIndex: widget.initialIndex,
                ),
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: Image.asset(
                  'assets/video poster.png', // Using a placeholder video poster
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 40, // Fixed height for 2 lines of text
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  widget.video.title,
                  style: GoogleFonts.lato(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

