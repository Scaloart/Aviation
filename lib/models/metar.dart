import 'package:xml/xml.dart';

class Metar {
  final String rawText;
  final String stationId;
  final DateTime observationTime;
  final double? tempC;
  final double? dewpointC;
  final int? windDirDegrees;
  final int? windSpeedKt;
  final double? visibilityStatuteMi;
  final double? altimInHg;
  final String? flightCategory;

  Metar({
    required this.rawText,
    required this.stationId,
    required this.observationTime,
    this.tempC,
    this.dewpointC,
    this.windDirDegrees,
    this.windSpeedKt,
    this.visibilityStatuteMi,
    this.altimInHg,
    this.flightCategory,
  });

  factory Metar.fromXmlElement(XmlElement element) {
    return Metar(
      rawText: element.findElements('raw_text').first.innerText,
      stationId: element.findElements('station_id').first.innerText,
      observationTime: DateTime.parse(element.findElements('observation_time').first.innerText),
      tempC: double.tryParse(element.findElements('temp_c').firstOrNull?.innerText ?? ''),
      dewpointC: double.tryParse(element.findElements('dewpoint_c').firstOrNull?.innerText ?? ''),
      windDirDegrees: int.tryParse(element.findElements('wind_dir_degrees').firstOrNull?.innerText ?? ''),
      windSpeedKt: int.tryParse(element.findElements('wind_speed_kt').firstOrNull?.innerText ?? ''),
      visibilityStatuteMi: double.tryParse(element.findElements('visibility_statute_mi').firstOrNull?.innerText ?? ''),
      altimInHg: double.tryParse(element.findElements('altim_in_hg').firstOrNull?.innerText ?? ''),
      flightCategory: element.findElements('flight_category').firstOrNull?.innerText,
    );
  }
}
