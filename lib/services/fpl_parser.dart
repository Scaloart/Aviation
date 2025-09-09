import '../models/fpl_data.dart';

class FplParser {
  static FplData parse(String rawFpl) {
    final text = rawFpl.replaceAll(RegExp(r'^\s*\(|\)\s*$'), '').replaceAll('\n', ' ').trim();

    try {
      final fields = text.split('-');

      if (fields.length < 8) return FplData();

      final aircraftId = fields[1];
      final flightRules = fields[2].substring(0, 1);
      final typeOfFlight = fields[2].substring(1);

      final aircraftAndEquip = fields[3].split('/');
      final aircraftType = aircraftAndEquip[0];
      final equipment = aircraftAndEquip.length > 1 ? aircraftAndEquip[1] : null;

      final departureAerodrome = fields[4].substring(0, 4);
      final departureTime = fields[4].substring(4);

      final speedAndLevel = fields[5];
      final cruisingSpeed = speedAndLevel.substring(0, 5);
      final flightLevel = speedAndLevel.substring(5);

      final route = fields[6];

      final destFieldParts = fields[7].split(' ');
      final destinationAerodrome = destFieldParts[0].substring(0, 4);
      final totalEet = destFieldParts[0].substring(4);
      final altnAerodrome = destFieldParts.length > 1 ? destFieldParts[1] : null;
      final secondAltnAerodrome = destFieldParts.length > 2 ? destFieldParts[2] : null;

      final Map<String, String> otherInfo = {};
      if (fields.length > 8) {
        final otherInfoString = fields.sublist(8).join('-');
        final otherInfoParts = otherInfoString.split(RegExp(r'\s+(?=[A-Z]+\/)'));
        for (var part in otherInfoParts) {
          final keyValue = part.split('/');
          if (keyValue.length > 1) {
            otherInfo[keyValue[0]] = keyValue.sublist(1).join('/');
          }
        }
      }

      return FplData(
        aircraftId: aircraftId,
        flightRules: flightRules,
        typeOfFlight: typeOfFlight,
        aircraftType: aircraftType,
        equipment: equipment,
        departureAerodrome: departureAerodrome,
        departureTime: departureTime,
        cruisingSpeed: cruisingSpeed,
        flightLevel: flightLevel,
        route: route,
        destinationAerodrome: destinationAerodrome,
        totalEet: totalEet,
        altnAerodrome: altnAerodrome,
        secondAltnAerodrome: secondAltnAerodrome,
        otherInfo: otherInfo,
      );
    } catch (e) {
      // Return empty FplData if any error occurs during parsing.
      return FplData();
    }
  }
}
