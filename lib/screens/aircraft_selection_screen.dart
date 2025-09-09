import 'package:flutter/material.dart';
import 'package:brie_fly/widgets/background_container.dart';

class AircraftSelectionScreen extends StatelessWidget {
  const AircraftSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BackgroundContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('DA 40NG / 42VI'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: Text('Aircraft Selection Content Coming Soon', style: TextStyle(color: Colors.white, fontSize: 24)),
        ),
      ),
    );
  }
}

