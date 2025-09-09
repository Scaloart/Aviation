class AirportService {

  // This service is currently unused. The app is using a local static airport list.
  // The implementation is commented out to prevent compilation errors.
  /*
  static Future<List<Airport>> searchAirports(String query) async {
    if (query.isEmpty) {
      return [];
    }

    final uri = Uri.parse('$_apiUrl?q=$query&api_key=$_apiKey');

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('response') && data['response'] is List) {
          final List<dynamic> airports = data['response'];
          // The fromJson method was removed from the Airport model.
          // return airports.map((json) => Airport.fromJson(json)).toList();
          return []; // Return empty list to satisfy function signature
        } else {
          print('API response did not contain a valid airport list. Body: ${response.body}');
          return [];
        }
      } else {
        print('Failed to load airports: ${response.statusCode}. Body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching airports: $e');
      return [];
    }
  }
  */
}
