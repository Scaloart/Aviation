class FplData {
  final String? aircraftId;
  final String? flightRules;
  final String? typeOfFlight;
  final String? aircraftType;
  final String? equipment;
  final String? departureAerodrome;
  final String? departureTime;
  final String? cruisingSpeed;
  final String? flightLevel;
  final String? route;
  final String? destinationAerodrome;
  final String? totalEet;
  final String? altnAerodrome;
  final String? secondAltnAerodrome;
  final Map<String, String> otherInfo;

  FplData({
    this.aircraftId,
    this.flightRules,
    this.typeOfFlight,
    this.aircraftType,
    this.equipment,
    this.departureAerodrome,
    this.departureTime,
    this.cruisingSpeed,
    this.flightLevel,
    this.route,
    this.destinationAerodrome,
    this.totalEet,
    this.altnAerodrome,
    this.secondAltnAerodrome,
    this.otherInfo = const {},
  });

  @override
  String toString() {
    return 'FplData(\n'
        '  aircraftId: $aircraftId,\n'
        '  flightRules: $flightRules,\n'
        '  typeOfFlight: $typeOfFlight,\n'
        '  aircraftType: $aircraftType,\n'
        '  equipment: $equipment,\n'
        '  departureAerodrome: $departureAerodrome,\n'
        '  departureTime: $departureTime,\n'
        '  cruisingSpeed: $cruisingSpeed,\n'
        '  flightLevel: $flightLevel,\n'
        '  route: $route,\n'
        '  destinationAerodrome: $destinationAerodrome,\n'
        '  totalEet: $totalEet,\n'
        '  altnAerodrome: $altnAerodrome,\n'
        '  secondAltnAerodrome: $secondAltnAerodrome,\n'
        '  otherInfo: $otherInfo\n'
        ')';
  }
}
