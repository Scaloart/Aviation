class FlightInfo {
  String crew;
  String aircraft;
  String cnpl;
  String ttsd;
  String ttsdHrs;
  String ttsa;
  String ttsaHrs;
  String fl;
  String date;
  String off;
  String offZ;
  String on;
  String onZ;
  String fuelOnBoard;
  String tio;
  String tioZ;
  String ldg;
  String ldgZ;

  FlightInfo({
    this.crew = '',
    this.aircraft = '',
    this.cnpl = '',
    this.ttsd = '',
    this.ttsdHrs = 'HRS',
    this.ttsa = '',
    this.ttsaHrs = 'HRS',
    this.fl = '',
    this.date = '',
    this.off = '',
    this.offZ = 'Z',
    this.on = '',
    this.onZ = 'Z',
    this.fuelOnBoard = '',
    this.tio = '',
    this.tioZ = 'Z',
    this.ldg = '',
    this.ldgZ = 'Z',
  });
}
