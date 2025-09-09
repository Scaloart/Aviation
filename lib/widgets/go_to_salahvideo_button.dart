import 'package:flutter/material.dart';
import 'package:brie_fly/screens/salahvideo.dart';

// This widget can be placed anywhere for testing
class GoToSalahVideoButton extends StatelessWidget {
  const GoToSalahVideoButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.ondemand_video),
      label: const Text('Salah Video Player'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PlayerShell()),
        );
      },
    );
  }
}

