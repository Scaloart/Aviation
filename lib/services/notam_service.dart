import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/notam_model.dart';

class NotamService {
  final String _clientId = '3a6ecc54764242efa085e1a6e36e3650';
  final String _clientSecret = '34c9adD8eBFa4F459Ac5A0F426098802';
  final String _baseUrl = 'https://external-api.faa.gov/notamapi/v1/notams';

  Future<List<Notam>> fetchNotams(String icaoCode) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      // The API requires a comma-separated list with no spaces.
      'icaoLocation': icaoCode.replaceAll(' ', ''),
      'responseFormat': 'geoJson',
      'pageSize': '50', // Optional: Fetch up to 50 NOTAMs
    });

    try {
      final response = await http.get(uri, headers: {
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['items'] as List? ?? []).map((item) {
          final properties = item['properties'] as Map<String, dynamic>? ?? {};
          final coreNotamData = properties['coreNOTAMData'] as Map<String, dynamic>? ?? {};
          final notamData = coreNotamData['notam'] as Map<String, dynamic>? ?? {};
          return Notam.fromJson(notamData);
        }).toList();
      } else {
        // Provide a more detailed error message
        throw Exception('Failed to load NOTAMs. Status Code: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('An error occurred in NotamService: $e');
      rethrow;
    }
  }
}
