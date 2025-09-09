import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/widgets/background_container.dart';

import 'english_l4_task_screen.dart';

/// Update this list with the exact folder names from your local path
/// C:\\Users\\slwdw\\Desktop\\Media For app\\ENGLISH L4\\last
const List<String> englishL4Folders = <String>[
  'TASK 1 PICTURES',
  'TASK 2 DIALOGUES & QUESTIONS',
  'TASK 3 PRONOUNCIATION',
  'TASK 4 READBACKS',
  'TASK 5 SHORT STORIES',
  'TASK 6 TRAFFIC ANIMATION',
  'TASK 7 SHORT QUESTIONS',
  'TASK_Announcements',
];

// Files per folder, sourced from user's PowerShell output, sorted numerically
const Map<String, List<String>> englishL4Files = {
  'TASK 1 PICTURES': [
    '1.mp4','2.mp4','3.mp4','4.mp4','5.mp4','6.mp4','7.mp4','8.mp4','9.mp4','10.mp4',
    '11.mp4','12.mp4','13.mp4','14.mp4','15.mp4','16.mp4','17.mp4','18.mp4','19.mp4','20.mp4',
    '21.mp4','22.mp4','23.mp4','24.mp4','25.mp4','26.mp4','27.mp4','28.mp4','29.mp4','30.mp4',
    '31.mp4','32.mp4','33.mp4','34.mp4','35.mp4','36.mp4','37.mp4','38.mp4','39.mp4','40.mp4',
    '41.mp4','42.mp4','43.mp4','44.mp4','45.mp4','46.mp4','47.mp4','48.mp4','49.mp4','50.mp4',
    '51.mp4','52.mp4','53.mp4',
  ],
  'TASK 2 DIALOGUES & QUESTIONS': [
    '1.mp4','2.mp4','3.mp4','4.mp4','5.mp4','6.mp4','7.mp4',
  ],
  'TASK 3 PRONOUNCIATION': [
    '1.mp4','2.mp4','3.mp4','4.mp4','5.mp4','6.mp4','7.mp4','8.mp4','9.mp4','10.mp4',
    '11.mp4','12.mp4','13.mp4','14.mp4','15.mp4','16.mp4','17.mp4','18.mp4','19.mp4','20.mp4',
    '21.mp4',
  ],
  'TASK 4 READBACKS': [
    '1.mp4','2.mp4','3.mp4','4.mp4','5.mp4','6.mp4','7.mp4','8.mp4','9.mp4','10.mp4','11.mp4','12.mp4','13.mp4','14.mp4',
  ],
  'TASK 5 SHORT STORIES': [
    '1.mp4','2.mp4','3.mp4','4.mp4','5.mp4','6.mp4',
  ],
  'TASK 6 TRAFFIC ANIMATION': [
    '1.mp4','2.mp4','3.mp4','4.mp4','5.mp4','6.mp4','7.mp4','8.mp4','9.mp4','10.mp4',
    '11.mp4','12.mp4','13.mp4','14.mp4','15.mp4','16.mp4','17.mp4','18.mp4','19.mp4','20.mp4',
    '21.mp4','22.mp4','23.mp4','24.mp4','25.mp4','26.mp4','27.mp4','28.mp4','29.mp4','30.mp4',
    '31.mp4','32.mp4','33.mp4','34.mp4','35.mp4',
  ],
  'TASK 7 SHORT QUESTIONS': [
    '1.mp4','2.mp4','3.mp4','4.mp4','5.mp4','6.mp4','7.mp4','8.mp4','9.mp4','10.mp4',
    '11.mp4','12.mp4','13.mp4','14.mp4','15.mp4','16.mp4','17.mp4','18.mp4','19.mp4','20.mp4',
    '21.mp4','22.mp4','23.mp4','24.mp4','25.mp4','26.mp4','27.mp4','28.mp4','29.mp4',
  ],
  'TASK_Announcements': [
    '1.mp4','2.mp4','3.mp4','4.mp4','5.mp4','6.mp4',
  ],
};

class EnglishL4Screen extends StatefulWidget {
  const EnglishL4Screen({super.key});

  @override
  State<EnglishL4Screen> createState() => _EnglishL4ScreenState();
}

class _EnglishL4ScreenState extends State<EnglishL4Screen> {

  @override
  Widget build(BuildContext context) {
    return BackgroundContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('English Level 4', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // On wide screens (desktop/tablet), center content with a max width
              final double maxContentWidth = constraints.maxWidth >= 900 ? 720 : constraints.maxWidth;
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: _buildFolderGrid(context, englishL4Folders),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFolderGrid(BuildContext context, List<String> items) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180, // ~2 per row on phones, more on larger screens
        crossAxisSpacing: 6,
        mainAxisSpacing: 8,
        mainAxisExtent: 176, // a bit taller to fit icon + 2-line label
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final name = items[index];
        return LayoutBuilder(
          builder: (context, constraints) {
            final double iconSize = (constraints.maxWidth * 0.7).clamp(88.0, 120.0);
            return InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EnglishL4TaskScreen(
                    folderName: name,
                    files: englishL4Files[name] ?? const <String>[],
                  ),
                ),
              ),
              borderRadius: BorderRadius.circular(8),
              child: Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.folder, color: Colors.amberAccent, size: iconSize),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: constraints.maxWidth - 8,
                      height: 38, // reserve space for up to 2 lines
                      child: Center(
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          softWrap: true,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}


