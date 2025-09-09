import 'dart:io';

class DossierInfo {
  final String id;
  final DateTime productionDate;
  final String name;
  final String category;
  final String filePath;
  final List<String> departAirportCodes;
  final List<String> arriveeAirportCodes;
  final List<String> enRouteAirportCodes;
  final List<String> selectedOptions;

  DossierInfo({
    required this.id,
    required this.productionDate,
    required this.name,
    required this.category,
    required this.filePath,
    required this.departAirportCodes,
    required this.arriveeAirportCodes,
    required this.enRouteAirportCodes,
    required this.selectedOptions,
  });

  factory DossierInfo.fromJson(Map<String, dynamic> json) {
    return DossierInfo(
      id: json['id'],
      productionDate: DateTime.parse(json['productionDate']),
      name: json['name'],
      category: json['category'],
      filePath: json['filePath'],
      departAirportCodes: List<String>.from(json['departAirportCodes'] ?? []),
      arriveeAirportCodes: List<String>.from(json['arriveeAirportCodes'] ?? []),
      enRouteAirportCodes: List<String>.from(json['enRouteAirportCodes'] ?? []),
      selectedOptions: List<String>.from(json['selectedOptions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productionDate': productionDate.toIso8601String(),
      'name': name,
      'category': category,
      'filePath': filePath,
      'departAirportCodes': departAirportCodes,
      'arriveeAirportCodes': arriveeAirportCodes,
      'enRouteAirportCodes': enRouteAirportCodes,
      'selectedOptions': selectedOptions,
    };
  }

  File get file => File(filePath);

  DossierInfo copyWith({
    String? id,
    DateTime? productionDate,
    String? name,
    String? category,
    String? filePath,
    List<String>? departAirportCodes,
    List<String>? arriveeAirportCodes,
    List<String>? enRouteAirportCodes,
    List<String>? selectedOptions,
  }) {
    return DossierInfo(
      id: id ?? this.id,
      productionDate: productionDate ?? this.productionDate,
      name: name ?? this.name,
      category: category ?? this.category,
      filePath: filePath ?? this.filePath,
      departAirportCodes: departAirportCodes ?? this.departAirportCodes,
      arriveeAirportCodes: arriveeAirportCodes ?? this.arriveeAirportCodes,
      enRouteAirportCodes: enRouteAirportCodes ?? this.enRouteAirportCodes,
      selectedOptions: selectedOptions ?? this.selectedOptions,
    );
  }
}
