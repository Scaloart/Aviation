import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
// No navigation controls here; only window controls and logo.

class AppWindowBar extends StatelessWidget {
  const AppWindowBar({
    super.key,
    this.buttonColors,
    this.closeButtonColors,
  });

  final WindowButtonColors? buttonColors;
  final WindowButtonColors? closeButtonColors;

  static const double height = 40.0;

  @override
  Widget build(BuildContext context) {
    final WindowButtonColors effectiveButtonColors = buttonColors ?? WindowButtonColors(
      iconNormal: Colors.white.withOpacity(0.75),
      mouseOver: Colors.white.withOpacity(0.06),
      mouseDown: Colors.white.withOpacity(0.10),
      iconMouseOver: Colors.white,
      iconMouseDown: Colors.white,
    );
    final WindowButtonColors effectiveCloseButtonColors = closeButtonColors ?? WindowButtonColors(
      mouseOver: const Color(0x44D32F2F), // translucent red on hover
      mouseDown: const Color(0x66B71C1C), // slightly stronger on press
      iconNormal: Colors.white.withOpacity(0.75),
      iconMouseOver: Colors.white,
    );

    return SizedBox(
      height: height,
      child: WindowTitleBarBox(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Drag area spanning full width
            Positioned.fill(
              child: MoveWindow(child: const SizedBox.expand()),
            ),

            // No back button in the window bar

            // Centered logo only (no title)
            IgnorePointer(
              ignoring: true, // allow drag through the center
              child: Image.asset(
                'assets/Logos/logo.png',
                height: 18,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                filterQuality: FilterQuality.high,
              ),
            ),

            // Right-aligned window buttons
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MinimizeWindowButton(colors: effectiveButtonColors),
                  MaximizeWindowButton(colors: effectiveButtonColors),
                  CloseWindowButton(colors: effectiveCloseButtonColors),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
