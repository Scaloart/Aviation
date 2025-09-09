class AerodromeChart {
  final String name;
  final List<String> pdfPaths;

  AerodromeChart({required this.name, this.pdfPaths = const []});

  factory AerodromeChart.fromJson(Map<String, dynamic> json) {
    return AerodromeChart(
      name: json['name'] ?? '',
      pdfPaths: List<String>.from(json['pdfPaths'] ?? []),
    );
  }
}

class Aerodrome {
  final String oaciCode;
  final String name;
  final List<AerodromeChart> charts;

  Aerodrome({
    required this.oaciCode,
    required this.name,
    this.charts = const [],
  });

  factory Aerodrome.fromJson(Map<String, dynamic> json) {
    var chartsFromJson = json['charts'] as List? ?? [];
    List<AerodromeChart> chartList = chartsFromJson.map((i) => AerodromeChart.fromJson(i)).toList();

    return Aerodrome(
      oaciCode: json['oaciCode'] ?? '',
      name: json['name'] ?? '',
      charts: chartList,
    );
  }
}
