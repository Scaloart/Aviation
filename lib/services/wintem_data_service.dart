import '../models/wintem_chart_model.dart';

class WintemDataService {
  static const String _baseUrl = 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/owintem/PW';

  static const Map<String, String> _areaCodes = {
    'Nord Atlantique': 'A',
    'Europe': 'B',
    'Asie Europe Nord Afrique': 'C',
    'Europe Sud Amerique': 'D',
    'Afrique Sud Amerique Europe': 'E',
    'Indochine': 'G',
    'Atlantique Amerique Nord Sud': 'N',
    'Europe Afrique': 'R',
    'Pacific': 'Y',
    'Asie': 'Z',
  };

  static const Map<String, String> _timeCodes = {
    '00:00': 'C',
    '06:00': 'D',
    '12:00': 'E',
    '18:00': 'F',
  };

  static const Map<String, String> _flCodes = {
    'FL 050': '8512',
    'FL 100': '7012',
    'FL 140': '6012',
    'FL 180': '5012',
    'FL 240': '4012',
    'FL 270': '3512',
    'FL 300': '3012',
    'FL 340': '2512',
    'FL 360': '2212',
    'FL 390': '2012',
    'FL 450': '1512',
    'FL 530': '1012',
  };

  List<WintemArea> getEnRouteCharts() {
    return _areaCodes.keys.map((area) {
      return WintemArea(
        area: area,
        flightLevels: _flCodes.keys.map((fl) {
          return WintemFlightLevel(
            level: fl,
            times: _timeCodes.keys.map((time) {
              final areaCode = _areaCodes[area]!;
              final timeCode = _timeCodes[time]!;
              final flCode = _flCodes[fl]!;
              final imageUrl = '$_baseUrl$areaCode$timeCode${flCode}GM.jpg';
              return WintemChartTime(label: time, imageUrl: imageUrl);
            }).toList(),
          );
        }).toList(),
      );
    }).toList();
  }

  static const String _marocBaseUrl = 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/mwintem/QWM';

  static const Map<String, String> _marocTimeCodes = {
    '00:00': 'A',
    '03:00': 'E',
    '06:00': 'D',
    '09:00': 'F',
    '12:00': 'C',
    '15:00': 'G',
    '18:00': 'B',
    '21:00': 'H',
  };

  static const Map<String, String> _marocFlCodes = {
    'FL 020': '9500',
    'FL 050': '8500',
    'FL 100': '7000',
    'FL 150': '6000',
    'FL 180': '5000',
    'FL 240': '4000',
    'FL 300': '3000',
    'FL 340': '2500',
    'FL 390': '2000',
    'FL 450': '1500',
    'FL 530': '1000',
  };

  List<WintemArea> getMarocCharts() {
    final marocFlightLevels = _marocFlCodes.keys.map((fl) {
      return WintemFlightLevel(
        level: fl,
        times: _marocTimeCodes.keys.map((time) {
          final timeCode = _marocTimeCodes[time]!;
          final flCode = _marocFlCodes[fl]!;
          final imageUrl = '$_marocBaseUrl$timeCode${flCode}GM.jpg';
          return WintemChartTime(label: time, imageUrl: imageUrl);
        }).toList(),
      );
    }).toList();

    return [WintemArea(area: 'Maroc', flightLevels: marocFlightLevels)];
  }
}
