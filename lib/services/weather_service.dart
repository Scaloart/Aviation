import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/metar.dart';
import '../models/taf.dart';

class WeatherService {
  static const String _baseUrl = 'https://aviationweather.gov/api/data';

  Future<Map<String, Metar>> fetchMetars(String airportCodes) async {
    final url = Uri.parse('$_baseUrl/metar?ids=$airportCodes&format=xml&hoursBeforeNow=1');
    final Map<String, Metar> metars = {};
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        try {
          final document = XmlDocument.parse(response.body);
          final metarElements = document.findAllElements('METAR');
          for (var metarElement in metarElements) {
            final metar = Metar.fromXmlElement(metarElement);
            final stationId = metarElement.findElements('station_id').first.innerText;
            metars[stationId] = metar;
          }
        } catch (e) {
          log('Error PARSING METARs for $airportCodes: $e');
          log('Response body: ${response.body}');
        }
      } else {
        log('Error fetching METARs for $airportCodes: StatusCode ${response.statusCode}');
      }
    } catch (e) {
      log('Network error fetching METARs for $airportCodes: $e');
    }
    return metars;
  }

  Future<Map<String, Taf>> fetchTafs(String airportCodes) async {
    final url = Uri.parse('$_baseUrl/taf?ids=$airportCodes&format=xml&hoursBeforeNow=12');
    final Map<String, Taf> tafs = {};
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        // ALWAYS LOG THE RESPONSE FOR DEBUGGING
        log('TAF API Response for $airportCodes:\n${response.body}');

        try {
          final document = XmlDocument.parse(response.body);
          final tafElements = document.findAllElements('TAF');

          if (tafElements.isEmpty) {
            log('No <TAF> elements found in the response for $airportCodes.');
          }

          for (var tafElement in tafElements) {
            final taf = Taf.fromXmlElement(tafElement);
            // Use the stationId from the parsed TAF object for consistency
            tafs[taf.stationId] = taf;
          }
        } catch (e) {
          log('Error PARSING TAFs for $airportCodes: $e');
          // The body is already logged above
        }
      } else {
        log('Error fetching TAFs for $airportCodes: StatusCode ${response.statusCode}');
      }
    } catch (e) {
      log('Network error fetching TAFs for $airportCodes: $e');
    }
    return tafs;
  }
}
