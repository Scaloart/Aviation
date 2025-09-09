import '../models/temsi_chart_model.dart';

class TemsiDataService {
  List<TemsiChartRegion> getEnRouteCharts() {
    return [
      TemsiChartRegion(
        region: 'Nord Atlantique',
        times: [
          TemsiChartTime(label: '00:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGAE0500GM.jpg?20250715174031'),
          TemsiChartTime(label: '06:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGAE0506GM.jpg?20250715174031'),
          TemsiChartTime(label: '12:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGAE0512GM.jpg?20250715174031'),
          TemsiChartTime(label: '18:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGAE0518GM.jpg?20250715174031'),
        ],
      ),
      TemsiChartRegion(
        region: 'Europe',
        times: [
          TemsiChartTime(label: '00:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGDE1400GM.jpg?20250715174240'),
          TemsiChartTime(label: '06:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGDE1406GM.jpg?20250715174240'),
          TemsiChartTime(label: '12:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGDE1412GM.jpg?20250715174240'),
          TemsiChartTime(label: '18:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGDE1418GM.jpg?20250715174240'),
        ],
      ),
      TemsiChartRegion(
        region: 'Amérique',
        times: [
          TemsiChartTime(label: '00:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGEE0700GM.jpg?20250715174706'),
          TemsiChartTime(label: '06:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGEE0706GM.jpg?20250715174706'),
          TemsiChartTime(label: '12:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGEE0712GM.jpg?20250715174706'),
          TemsiChartTime(label: '18:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGEE0718GM.jpg?20250715174706'),
        ],
      ),
      TemsiChartRegion(
        region: 'Nord Atlantique / Niveau Moyen',
        times: [
          TemsiChartTime(label: '00:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGNE1400GM.jpg?20250715174850'),
          TemsiChartTime(label: '06:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGNE1406GM.jpg?20250715174850'),
          TemsiChartTime(label: '12:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGNE1412GM.jpg?20250715174850'),
          TemsiChartTime(label: '18:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGNE1418GM.jpg?20250715174850'),
        ],
      ),
      TemsiChartRegion(
        region: 'Europe + Afrique',
        times: [
          TemsiChartTime(label: '00:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGRE0500GM.jpg?20250715175446'),
          TemsiChartTime(label: '06:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGRE0506GM.jpg?20250715175446'),
          TemsiChartTime(label: '12:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGRE0512GM.jpg?20250715175446'),
          TemsiChartTime(label: '18:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGRE0518GM.jpg?20250715175446'),
        ],
      ),
      TemsiChartRegion(
        region: 'Europe + Amérique',
        times: [
          TemsiChartTime(label: '00:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGSE0500GM.jpg?20250715175520'),
          TemsiChartTime(label: '06:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGSE0506GM.jpg?20250715175520'),
          TemsiChartTime(label: '12:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGSE0512GM.jpg?20250715175520'),
          TemsiChartTime(label: '18:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGSE0518GM.jpg?20250715175520'),
        ],
      ),
      TemsiChartRegion(
        region: 'Europe + Afrique + Asie',
        times: [
          TemsiChartTime(label: '00:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGZE0500GM.jpg?20250715175613'),
          TemsiChartTime(label: '06:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGZE0506GM.jpg?20250715175613'),
          TemsiChartTime(label: '12:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGZE0512GM.jpg?20250715175613'),
          TemsiChartTime(label: '18:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGZE0518GM.jpg?20250715175613'),
        ],
      ),
      TemsiChartRegion(
        region: 'Australie',
        times: [
          TemsiChartTime(label: '00:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGGE0500GM.jpg?20250715175701'),
          TemsiChartTime(label: '06:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGGE0506GM.jpg?20250715175701'),
          TemsiChartTime(label: '12:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGGE0512GM.jpg?20250715175701'),
          TemsiChartTime(label: '18:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGGE0518GM.jpg?20250715175701'),
        ],
      ),
      TemsiChartRegion(
        region: 'Antarctique',
        times: [
          TemsiChartTime(label: '00:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGJE0500GM.jpg?20250715175723'),
          TemsiChartTime(label: '06:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGJE0506GM.jpg?20250715175723'),
          TemsiChartTime(label: '12:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGJE0512GM.jpg?20250715175723'),
          TemsiChartTime(label: '18:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGJE0518GM.jpg?20250715175723'),
        ],
      ),
      TemsiChartRegion(
        region: 'Asie',
        times: [
          TemsiChartTime(label: '00:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGCE0500GM.jpg?20250715175745'),
          TemsiChartTime(label: '06:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGCE0506GM.jpg?20250715175745'),
          TemsiChartTime(label: '12:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGCE0512GM.jpg?20250715175745'),
          TemsiChartTime(label: '18:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGCE0518GM.jpg?20250715175745'),
        ],
      ),
      TemsiChartRegion(
        region: 'Indochine',
        times: [
          TemsiChartTime(label: '00:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGDE0500GM.jpg?20250715175849'),
          TemsiChartTime(label: '06:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGDE0506GM.jpg?20250715175849'),
          TemsiChartTime(label: '12:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGDE0512GM.jpg?20250715175849'),
          TemsiChartTime(label: '18:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/otemsi/PGDE0518GM.jpg?20250715175849'),
        ],
      ),
    ];
  }

  List<TemsiChartRegion> getBassesCouchesCharts() {
    return [
      TemsiChartRegion(
        region: 'Maroc TEMSI',
        times: [
          TemsiChartTime(label: '00:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/mtemsi/QGMC0024GM.jpg?20250715175925'),
          TemsiChartTime(label: '06:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/mtemsi/QGMC0030GM.jpg?20250715175925'),
          TemsiChartTime(label: '12:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/mtemsi/QGAM15GMMC.jpg?20250715175925'),
          TemsiChartTime(label: '18:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/mtemsi/QGMC0018GM.jpg?20250715175925'),
        ],
      ),
      TemsiChartRegion(
        region: 'Basses Couches TEMSI',
        times: [
          TemsiChartTime(label: '03:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/mtemsi/QGAJ60GMMC.jpg?20250715180004'),
          TemsiChartTime(label: '09:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/mtemsi/QGAL60GMMC.jpg?20250715180004'),
          TemsiChartTime(label: '15:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/mtemsi/QGAN60GMMC.jpg?20250715180004'),
          TemsiChartTime(label: '21:00', imageUrl: 'https://aero.marocmeteo.ma/samba/couches/archives/aeroweb/mtemsi/QGAH60GMMC.jpg?20250715180004'),
        ],
      ),
    ];
  }
}
