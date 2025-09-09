import 'package:flutter/material.dart';
import 'package:brie_fly/screens/da40/playlist_screen.dart';
import 'package:brie_fly/widgets/custom_video_player.dart';

class VideoPlayerScreen extends StatelessWidget {
  final Video video;

  const VideoPlayerScreen({Key? key, required this.video}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(video.title, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SizedBox.expand(
        child: CustomVideoPlayer(
          url: video.url,
          resolutions: video.resolutions,
        ),
      ),
    );
  }
}

