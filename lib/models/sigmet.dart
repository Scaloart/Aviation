class Sigmet {
  final String rawText;

  Sigmet({required this.rawText});

  factory Sigmet.fromJson(Map<String, dynamic> json) {
    return Sigmet(rawText: json['raw_text']);
  }
}
