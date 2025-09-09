import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:brie_fly/models/notam_model.dart';
import 'package:brie_fly/models/temsi_chart_model.dart';
import 'package:brie_fly/models/wintem_chart_model.dart';

import 'package:brie_fly/flight_plan_screen.dart';
import 'package:brie_fly/notam_config_screen.dart';
import 'package:brie_fly/temsi_config_screen.dart';
import 'package:brie_fly/wintem_config_screen.dart';
import 'package:brie_fly/weight_balance_screen.dart';
import 'package:brie_fly/screens/nav_log_screen.dart';
import 'package:brie_fly/screens/generated_dossier_screen.dart';

class NavigationService {
  // Global navigator key for root-level navigation (e.g., update gate)
  static final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

    static const List<String> dossierFlowOrder = [
    'METAR / TAF / SIGMET',
    'Carte TEMSI',
    'Carte WINTEM',
    'NOTAMs',
    'LOG de Navigation',
    'Plan de Vol',
    'Masse et Centrage',
  ];

  static bool isLastScreen(String currentScreen, List<String> selectedItems) {
    final currentIndex = dossierFlowOrder.indexOf(currentScreen);
    if (currentIndex == -1) return true;

    for (int i = currentIndex + 1; i < dossierFlowOrder.length; i++) {
      if (selectedItems.contains(dossierFlowOrder[i])) {
        return false;
      }
    }
    return true;
  }

  static Route? getFirstScreenRoute({
    required BuildContext context,
    required List<String> selectedItems,
    required String airportCodes,
  }) {
    String? firstScreen;
    for (final item in dossierFlowOrder) {
      if (selectedItems.contains(item)) {
        firstScreen = item;
        break;
      }
    }

    if (firstScreen == null) {
      // If no items are selected that are in the flow, go to the generated screen.
      return MaterialPageRoute(
        builder: (_) => GeneratedDossierScreen(
          selectedItems: selectedItems,
          airportCodes: airportCodes,
          selectedTemsiCharts: const [],
          selectedWintemCharts: const [],
          notams: const [],
        ),
      );
    }

    return _getRouteForScreen(
      screenName: firstScreen,
      context: context,
      selectedItems: selectedItems,
      airportCodes: airportCodes,
    );
  }

  static Route? getNextScreenRoute({
    required BuildContext context,
    required String currentScreen,
    required List<String> selectedItems,
    required String airportCodes,
    String? navLogPath,
    Uint8List? navLogBytes,
    String? flightPlanPath,
    Uint8List? flightPlanBytes,
    Uint8List? balanceSheetBytes,
    List<SelectedTemsiChart> selectedTemsiCharts = const [],
    List<SelectedWintemChart> selectedWintemCharts = const [],
    List<Notam> notams = const [],
  }) {
    String? nextScreen;
    final currentIndex = dossierFlowOrder.indexOf(currentScreen);

    if (currentIndex != -1) {
      for (int i = currentIndex + 1; i < dossierFlowOrder.length; i++) {
        if (selectedItems.contains(dossierFlowOrder[i])) {
          nextScreen = dossierFlowOrder[i];
          break;
        }
      }
    }

    if (nextScreen != null) {
      return _getRouteForScreen(
        screenName: nextScreen,
        context: context,
        selectedItems: selectedItems,
        airportCodes: airportCodes,
        navLogPath: navLogPath,
        navLogBytes: navLogBytes,
        flightPlanPath: flightPlanPath,
        flightPlanBytes: flightPlanBytes,
        balanceSheetBytes: balanceSheetBytes,
        selectedTemsiCharts: selectedTemsiCharts,
        selectedWintemCharts: selectedWintemCharts,
        notams: notams,
      );
    } else {
      // If no next screen, go to the final generated dossier screen
      return MaterialPageRoute(
        builder: (_) => GeneratedDossierScreen(
          selectedItems: selectedItems,
          airportCodes: airportCodes,
          navLogPath: navLogPath,
          navLogBytes: navLogBytes,
          flightPlanPath: flightPlanPath,
          flightPlanBytes: flightPlanBytes,
          balanceSheetBytes: balanceSheetBytes,
          selectedTemsiCharts: selectedTemsiCharts,
          selectedWintemCharts: selectedWintemCharts,
          notams: notams,
        ),
      );
    }
  }

  static Route? _getRouteForScreen({
    required String screenName,
    required BuildContext context,
    required List<String> selectedItems,
    required String airportCodes,
    String? navLogPath,
    Uint8List? navLogBytes,
    String? flightPlanPath,
    Uint8List? flightPlanBytes,
    Uint8List? balanceSheetBytes,
    List<SelectedTemsiChart> selectedTemsiCharts = const [],
    List<SelectedWintemChart> selectedWintemCharts = const [],
    List<Notam> notams = const [],
  }) {
    switch (screenName) {
            case 'METAR / TAF / SIGMET':
        // This data is shown in the final preview, so we skip to the next screen.
        return getNextScreenRoute(
          context: context,
          currentScreen: screenName,
          selectedItems: selectedItems,
          airportCodes: airportCodes,
          navLogPath: navLogPath,
          navLogBytes: navLogBytes,
          flightPlanPath: flightPlanPath,
          flightPlanBytes: flightPlanBytes,
          balanceSheetBytes: balanceSheetBytes,
          selectedTemsiCharts: selectedTemsiCharts,
          selectedWintemCharts: selectedWintemCharts,
          notams: notams,
        );
      case 'Carte TEMSI':
        return MaterialPageRoute(builder: (_) => TemsiConfigScreen(selectedItems: selectedItems, airportCodes: airportCodes));
      case 'Carte WINTEM':
        return MaterialPageRoute(builder: (_) => WintemConfigScreen(selectedItems: selectedItems, airportCodes: airportCodes, selectedTemsiCharts: selectedTemsiCharts));
      case 'NOTAMs':
        return MaterialPageRoute(builder: (_) => NotamConfigScreen(selectedItems: selectedItems, airportCodes: airportCodes, selectedTemsiCharts: selectedTemsiCharts, selectedWintemCharts: selectedWintemCharts));
      case 'LOG de Navigation':
        return MaterialPageRoute(builder: (_) => NavLogScreen(selectedItems: selectedItems, airportCodes: airportCodes, selectedTemsiCharts: selectedTemsiCharts, selectedWintemCharts: selectedWintemCharts, notams: notams, navLogPath: navLogPath, navLogBytes: navLogBytes, flightPlanPath: flightPlanPath, flightPlanBytes: flightPlanBytes, balanceSheetBytes: balanceSheetBytes));
      case 'Plan de Vol':
        return MaterialPageRoute(builder: (_) => FlightPlanScreen(selectedItems: selectedItems, airportCodes: airportCodes, selectedTemsiCharts: selectedTemsiCharts, selectedWintemCharts: selectedWintemCharts, notams: notams, navLogPath: navLogPath, navLogBytes: navLogBytes, flightPlanPath: flightPlanPath, flightPlanBytes: flightPlanBytes, balanceSheetBytes: balanceSheetBytes));
      case 'Masse et Centrage':
        return MaterialPageRoute(builder: (_) => WeightBalanceScreen(selectedItems: selectedItems, airportCodes: airportCodes, navLogPath: navLogPath, navLogBytes: navLogBytes, flightPlanPath: flightPlanPath ?? '', flightPlanBytes: flightPlanBytes, selectedTemsiCharts: selectedTemsiCharts, selectedWintemCharts: selectedWintemCharts, notams: notams, balanceSheetBytes: balanceSheetBytes));
      default:
        return null;
    }
  }
}
