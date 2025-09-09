import 'package:xml/xml.dart';

class Taf {
  final String rawText;
  final String stationId;
  final DateTime issueTime;
  final List<Forecast> forecasts;

  Taf({
    required this.rawText,
    required this.stationId,
    required this.issueTime,
    required this.forecasts,
  });

  factory Taf.fromXmlElement(XmlElement element) {
    // Helper to safely get text from an element
    String? safeGetText(String tagName) => element.getElement(tagName)?.innerText;

    // Safely parse all fields with fallbacks
    final stationId = safeGetText('station_id') ?? 'UKWN';
    final issueTimeText = safeGetText('issue_time');
    final issueTime = issueTimeText != null ? DateTime.parse(issueTimeText) : DateTime.now();
    final rawText = safeGetText('raw_text') ?? 'TAF data not available.';

    return Taf(
      rawText: rawText,
      stationId: stationId,
      issueTime: issueTime,
      forecasts: element
          .findElements('forecast')
          .map((e) => Forecast.fromXmlElement(e))
          .toList(),
    );
  }
}

class Forecast {
  final DateTime fcstTimeFrom;
  final DateTime fcstTimeTo;
  final int? windDirDegrees;
  final int? windSpeedKt;
  final double? visibilityStatuteMi;
  final String? wxString;
  final List<String> skyCondition;

  Forecast({
    required this.fcstTimeFrom,
    required this.fcstTimeTo,
    this.windDirDegrees,
    this.windSpeedKt,
    this.visibilityStatuteMi,
    this.wxString,
    required this.skyCondition,
  });

  factory Forecast.fromXmlElement(XmlElement element) {
    return Forecast(
      fcstTimeFrom: DateTime.parse(
          element.findElements('fcst_time_from').first.innerText),
      fcstTimeTo:
          DateTime.parse(element.findElements('fcst_time_to').first.innerText),
      windDirDegrees: int.tryParse(
          element.findElements('wind_dir_degrees').firstOrNull?.innerText ??
              ''),
      windSpeedKt: int.tryParse(
          element.findElements('wind_speed_kt').firstOrNull?.innerText ?? ''),
      visibilityStatuteMi: double.tryParse(element
              .findElements('visibility_statute_mi')
              .firstOrNull
              ?.innerText ??
          ''),
      wxString: element.findElements('wx_string').firstOrNull?.innerText,
      skyCondition: element
          .findElements('sky_condition')
          .map((e) =>
              '${e.getAttribute('sky_cover')!} @ ${e.getAttribute('cloud_base_ft_agl')!}ft')
          .toList(),
    );
  }
}
