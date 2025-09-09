class Airport {
  final String name;
  final String icaoCode;
  final String countryCode;

  const Airport({
    required this.name,
    required this.icaoCode,
    required this.countryCode,
  });

  @override
  String toString() {
    return 'Airport{name: $name, icaoCode: $icaoCode, country: $countryCode}';
  }
}
