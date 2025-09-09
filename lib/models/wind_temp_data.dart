class FlightLevelData {
  final String flightLevel;
  final List<WindTempInfo> windData;

  FlightLevelData({required this.flightLevel, required this.windData});
}

class WindTempInfo {
  final String station;
  final String wind;
  final String temp;

  WindTempInfo({required this.station, required this.wind, required this.temp});
}
