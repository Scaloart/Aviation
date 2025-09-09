import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/airport_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  static final String _logDir = Platform.environment['LOCALAPPDATA'] != null
      ? join(Platform.environment['LOCALAPPDATA']!, 'BrieFly')
      : Directory.systemTemp.path;
  static final String _logFilePath = join(_logDir, 'startup.log');

  Future<void> _log(String message) async {
    try {
      final ts = DateTime.now().toIso8601String();
      await Directory(_logDir).create(recursive: true);
      final f = File(_logFilePath);
      await f.writeAsString('[$ts] $message\n', mode: FileMode.append, flush: true);
    } catch (_) {
      // ignore logging errors
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    // Initialize FFI on desktop to ensure sqlite3 DLL is loaded (from sqlite3_flutter_libs)
    // Also force databases path to a user-writable location to avoid Program Files/.dart_tool defaults.
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        sqfliteFfiInit();
      } catch (_) {
        // ignore, continue - some environments auto-init
      }

      try {
        // Choose a writable base dir for DBs
        final base = Platform.environment['LOCALAPPDATA'] ??
            Platform.environment['APPDATA'] ??
            Directory.systemTemp.path;
        final dbDir = join(base, 'BrieFly', 'databases');
        await Directory(dbDir).create(recursive: true);
        // Point sqflite FFI to that dir
        databaseFactoryFfi.setDatabasesPath(dbDir);
        await _log('Configured FFI databases path: ' + dbDir);
      } catch (e) {
        await _log('Failed to set FFI databases path: ' + e.toString());
      }
    }

    // Use FFI factory to resolve DB path on desktop; default on mobile/web
    final dbPath = (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS))
        ? await databaseFactoryFfi.getDatabasesPath()
        : await getDatabasesPath();
    final path = join(dbPath, 'airports.db');
    await _log('DB target path: ' + path);

    // Check if the database exists
    final exists = await databaseExists(path);
    await _log('DB exists: ' + exists.toString());

    if (!exists) {
      print('Creating new copy from asset');
      await _log('Copying DB from asset (first install)');
      // Make sure the parent directory exists
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      // Copy from asset
      try {
        final ByteData data = await rootBundle.load('assets/airports.db');
        final List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes, flush: true);
        await _log('Asset copy success: ' + File(path).lengthSync().toString() + ' bytes');
      } catch (e) {
        // Asset not found or not bundled
        print('ERROR loading assets/airports.db: $e');
        await _log('ERROR loading assets/airports.db: ' + e.toString());
        rethrow;
      }
    } else {
      print('Opening existing database');
      await _log('Opening existing DB');
    }

    // Validate DB contents; if invalid or cannot open, recopy asset once
    Future<Database> openReadOnly() async {
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        return await databaseFactoryFfi.openDatabase(path, options: OpenDatabaseOptions(readOnly: true));
      } else {
        return await openDatabase(path, readOnly: true);
      }
    }

    Future<bool> _hasAirportsTable(Database db) async {
      try {
        final res = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='airports' LIMIT 1");
        return res.isNotEmpty;
      } catch (e) {
        await _log('Error checking airports table: ' + e.toString());
        return false;
      }
    }

    try {
      final db = await openReadOnly();
      final ok = await _hasAirportsTable(db);
      await db.close();
      if (!ok) {
        await _log('airports table missing; recopying asset');
        final data = await rootBundle.load('assets/airports.db');
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes, flush: true);
      }
    } catch (e) {
      await _log('DB open failed, recopying asset: ' + e.toString());
      try {
        final data = await rootBundle.load('assets/airports.db');
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes, flush: true);
      } catch (e2) {
        await _log('Asset recopy failed: ' + e2.toString());
        rethrow;
      }
    }

    await _log('Opening DB read-only for app use');
    return await openReadOnly();
  }

  Future<List<Airport>> searchAirports(String query) async {
    if (query.length < 2) return [];
    final db = await database;
    final processedQuery = query.toLowerCase();
    final List<Map<String, dynamic>> maps = await db.query(
      'airports',
      where: 'LOWER(name) LIKE ? OR LOWER(icao) LIKE ?',
      whereArgs: ['%$processedQuery%', '%$processedQuery%'],
      limit: 50,
    );

    if (maps.isEmpty) {
      return [];
    }

    return List.generate(maps.length, (i) {
      return Airport(
        name: maps[i]['name'] as String,
        icaoCode: maps[i]['icao'] as String,
        countryCode: maps[i]['country'] as String,
      );
    });
  }
}
