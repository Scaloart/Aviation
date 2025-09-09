class NavLogEntry {
  void updateField(String fieldName, String value) {
    switch (fieldName) {
      case 'waypoint':
        waypoint = value;
        break;
      case 'vorRad':
        vorRad = value;
        break;
      case 'vorDist':
        vorDist = value;
        break;
      case 'freq':
        freq = value;
        break;
      case 'dtk':
        dtk = value;
        break;
      case 'safeAlt':
        safeAlt = value;
        break;
      case 'distLeg':
        distLeg = value;
        break;
      case 'timingEte':
        timingEte = value;
        break;
      case 'timingAta':
        timingAta = value;
        break;
      case 'timingAte':
        timingAte = value;
        break;
      case 'fuelCons':
        fuelCons = value;
        break;
      case 'fuelCumul':
        fuelCumul = value;
        break;
      case 'ats':
        ats = value;
        break;
    }
  }

  String waypoint;
  String latLong;
  String vorRad;
  String vorDist;
  String freq;
  String dtk;
  String safeAlt;
  String distLeg;
  String distRem;
  String timingEte;
  String timingAte;
  String timingEta;
  String timingAta;
  String fuelCons;
  String fuelCumul;
  String ats;

  NavLogEntry({
    this.waypoint = '',
    this.latLong = '',
    this.vorRad = '',
    this.vorDist = '',
    this.freq = '',
    this.dtk = '',
    this.safeAlt = '',
    this.distLeg = '',
    this.distRem = '',
    this.timingEte = '',
    this.timingAte = '',
    this.timingEta = '',
    this.timingAta = '',
    this.fuelCons = '',
    this.fuelCumul = '',
    this.ats = '',
  });
}
