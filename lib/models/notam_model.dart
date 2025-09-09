// lib/models/notam_model.dart

class Notam {
  final String id;
  final String title;
  final String body;
  final String icaoLocation;
  final String classification;
  final bool isSelected;

  Notam({
    required this.id,
    required this.title,
    required this.body,
    required this.icaoLocation,
    required this.classification,
    this.isSelected = false,
  });

  // This factory now correctly parses the deeply nested 'notam' object.
  factory Notam.fromJson(Map<String, dynamic> json) {
    final notamNumber = json['number'] as String? ?? 'Unknown';
    final series = json['series'] as String? ?? '';
    final fullNotamId = '$series$notamNumber';

    return Notam(
      id: json['id'] as String? ?? 'No ID',
      title: fullNotamId.isNotEmpty ? fullNotamId : 'No Title Available',
      body: json['text'] as String? ?? 'No Body Available',
      icaoLocation: json['icaoLocation'] as String? ?? 'N/A',
      classification: json['classification'] as String? ?? 'Unknown',
    );
  }

  Notam copyWith({
    String? id,
    String? title,
    String? body,
    String? icaoLocation,
    String? classification,
    bool? isSelected,
  }) {
    return Notam(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      icaoLocation: icaoLocation ?? this.icaoLocation,
      classification: classification ?? this.classification,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Notam && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
