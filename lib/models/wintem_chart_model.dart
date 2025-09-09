import 'package:equatable/equatable.dart';

class WintemArea extends Equatable {
  final String area;
  final List<WintemFlightLevel> flightLevels;

  const WintemArea({required this.area, required this.flightLevels});

  @override
  List<Object> get props => [area, flightLevels];
}

class WintemFlightLevel extends Equatable {
  final String level;
  final List<WintemChartTime> times;

  const WintemFlightLevel({required this.level, required this.times});

  @override
  List<Object> get props => [level, times];
}

class WintemChartTime extends Equatable {
  final String label;
  final String imageUrl;

  const WintemChartTime({required this.label, required this.imageUrl});

  @override
  List<Object> get props => [label, imageUrl];
}

class SelectedWintemChart extends Equatable {
  final String? area;
  final String flightLevel;
  final String timeLabel;
  final String imageUrl;

  const SelectedWintemChart({
    this.area,
    required this.flightLevel,
    required this.timeLabel,
    required this.imageUrl,
  });

  @override
  List<Object?> get props => [area, flightLevel, timeLabel];
}
