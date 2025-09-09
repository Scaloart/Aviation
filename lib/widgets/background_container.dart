import 'dart:ui';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:brie_fly/widgets/ad_banner.dart';
import 'package:brie_fly/services/theme_service.dart';
import 'package:brie_fly/widgets/app_window_bar.dart';

class BackgroundContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool showBottomBanner;
  final bool padForBanner;

  const BackgroundContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.showBottomBanner = true,
    this.padForBanner = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, _) {
        final bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
        // Add some bottom padding to keep content clear of the bottom banner
        final EdgeInsetsGeometry basePadding = isDesktop
            ? padding.add(const EdgeInsets.only(top: AppWindowBar.height))
            : padding;
        final EdgeInsetsGeometry contentPadding = showBottomBanner && padForBanner
            ? basePadding.add(const EdgeInsets.only(bottom: 80))
            : basePadding;

        return Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(themeService.selectedBackground),
                    fit: BoxFit.cover,
                  ),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Padding(
                      padding: contentPadding,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
            if (isDesktop)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AppWindowBar(),
              ),
            if (showBottomBanner)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Center(child: AdBanner()),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

