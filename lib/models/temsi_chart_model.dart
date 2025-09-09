import 'package:equatable/equatable.dart';

class TemsiChartRegion extends Equatable {
  final String region;
  final List<TemsiChartTime> times;

  const TemsiChartRegion({required this.region, required this.times});

  @override
  List<Object> get props => [region, times];
}

class TemsiChartTime extends Equatable {
  final String label;
  final String imageUrl;

  const TemsiChartTime({required this.label, required this.imageUrl});

  @override
  List<Object> get props => [label, imageUrl];
}

class SelectedTemsiChart extends Equatable {
  final String region;
  final String timeLabel;
  final String imageUrl;

  const SelectedTemsiChart({
    required this.region,
    required this.timeLabel,
    required this.imageUrl,
  });

  @override
  List<Object?> get props => [region, timeLabel];
}
