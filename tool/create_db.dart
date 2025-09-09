import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  // Initialize FFI for sqflite on desktop
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;

  final projectRoot = Directory.current.path;
  final csvFilePath = p.join(projectRoot, 'airports.csv');
  final assetsDir = Directory(p.join(projectRoot, 'assets'));
  final dbPath = p.join(assetsDir.path, 'airports.db');

  final csvFile = File(csvFilePath);
  if (!await csvFile.exists()) {
    print(
        'Error: airports.csv not found. Please place it in the project root.');
    return;
  }

  if (!await assetsDir.exists()) {
    await assetsDir.create();
  }

  final dbFile = File(dbPath);
  if (await dbFile.exists()) {
    await dbFile.delete();
  }

  print('Creating database at $dbPath');
  final db = await databaseFactory.openDatabase(dbPath);

  try {
    await db.execute('''
      CREATE TABLE airports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icao TEXT NOT NULL,
        country TEXT NOT NULL
      )
    ''');

    print('Reading data from $csvFilePath...');
    final csvString = await csvFile.readAsString();
    final fields =
        const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
            .convert(csvString);

    if (fields.isEmpty) {
      print('Error: CSV file is empty or could not be parsed.');
      return;
    }

    final headers =
        fields.first.map((h) => h.toString().toLowerCase()).toList();
    final nameIndex = headers.indexOf('name');
    final icaoIndex =
        headers.indexOf('ident'); // ICAO code is in the 'ident' column
    final countryIndex = headers.indexOf('iso_country');
    final typeIndex = headers.indexOf('type');

    if ([nameIndex, icaoIndex, countryIndex, typeIndex].contains(-1)) {
      print('Error: CSV headers are missing required columns.');
      print('Expected `name`, `ident`, `iso_country`, and `type`.');
      return;
    }

    final batch = db.batch();
    int count = 0;
    final validTypes = {'small_airport', 'medium_airport', 'large_airport'};

    // Start from the second row to skip headers
    for (var i = 1; i < fields.length; i++) {
      final row = fields[i];
      if (row.length <= nameIndex ||
          row.length <= icaoIndex ||
          row.length <= countryIndex ||
          row.length <= typeIndex) {
        continue;
      }

      final type = row[typeIndex].toString().toLowerCase();
      final icao = row[icaoIndex].toString().trim();
      final name = row[nameIndex].toString().trim();
      final country = row[countryIndex].toString().trim();

      if (validTypes.contains(type) && icao.isNotEmpty && name.isNotEmpty) {
        batch.insert('airports', {
          'name': name,
          'icao': icao,
          'country': country,
        });
        count++;
      }
    }

    await batch.commit(noResult: true);
    print('Successfully inserted $count valid airport records.');
  } finally {
    await db.close();
    print('Database processing complete!');
  }
}
