import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:brie_fly/models/dossier_info.dart';

class DossierService {
  static const _jsonFileName = 'dossiers.json';

  Future<File> _getDossiersJsonFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final dossierDir = Directory('${directory.path}/dossiers');
    if (!await dossierDir.exists()) {
      await dossierDir.create(recursive: true);
    }
    return File('${dossierDir.path}/$_jsonFileName');
  }

  Future<List<DossierInfo>> _readDossiers() async {
    try {
      final file = await _getDossiersJsonFile();
      if (!await file.exists()) {
        return [];
      }
      final contents = await file.readAsString();
      if (contents.isEmpty) {
        return [];
      }
      final List<dynamic> jsonList = json.decode(contents);
      return jsonList.map((json) => DossierInfo.fromJson(json)).toList();
    } catch (e) {
      print('Error reading dossiers.json: $e');
      return [];
    }
  }

  Future<void> _writeDossiers(List<DossierInfo> dossiers) async {
    final file = await _getDossiersJsonFile();
    final jsonList = dossiers.map((d) => d.toJson()).toList();
    await file.writeAsString(json.encode(jsonList), flush: true);
  }

  Future<void> saveDossierInfo(DossierInfo dossierInfo) async {
    final dossiers = await _readDossiers();
    // Avoid duplicates
    dossiers.removeWhere((d) => d.id == dossierInfo.id);
    dossiers.add(dossierInfo);
    await _writeDossiers(dossiers);
  }

  Future<List<DossierInfo>> listDossiers() async {
    final dossiers = await _readDossiers();
    // Optional: Clean up entries where the file no longer exists
    final existingDossiers = <DossierInfo>[];
    for (final dossier in dossiers) {
      if (await dossier.file.exists()) {
        existingDossiers.add(dossier);
      }
    }

    if (existingDossiers.length != dossiers.length) {
      await _writeDossiers(existingDossiers);
    }

    existingDossiers.sort((a, b) => b.productionDate.compareTo(a.productionDate));
    return existingDossiers;
  }

  Future<void> renameDossier(DossierInfo dossierToRename, String newName) async {
    try {
      final oldFile = File(dossierToRename.filePath);
      if (!await oldFile.exists()) {
        throw Exception('Le fichier original du dossier n\'existe pas.');
      }

      // Create new path
      final directory = path.dirname(dossierToRename.filePath);
      final extension = path.extension(dossierToRename.filePath);
      final newFileName = '$newName$extension';
      final newFilePath = path.join(directory, newFileName);

      // Rename the file
      await oldFile.rename(newFilePath);

      // Update the metadata
      final dossiers = await _readDossiers();
      final index = dossiers.indexWhere((d) => d.id == dossierToRename.id);

      if (index != -1) {
        final updatedDossier = dossiers[index].copyWith(
          name: newName,
          filePath: newFilePath,
        );
        dossiers[index] = updatedDossier;
        await _writeDossiers(dossiers);
      } else {
        // If metadata not found, we should ideally revert the file rename,
        // but for now, we'll just throw an error.
        await File(newFilePath).rename(dossierToRename.filePath); // Revert rename
        throw Exception('Dossier non trouvé dans les métadonnées.');
      }
    } catch (e) {
      print('Erreur lors du renommage du dossier: $e');
      rethrow;
    }
  }

  Future<void> deleteAllDossiers() async {
    try {
      final dossiers = await _readDossiers();
      for (final dossier in dossiers) {
        final pdfFile = File(dossier.filePath);
        if (await pdfFile.exists()) {
          await pdfFile.delete();
        }
      }
      await _writeDossiers([]); // Write an empty list to the json file
    } catch (e) {
      print('Error deleting all dossiers: $e');
      rethrow;
    }
  }

  Future<void> deleteDossier(DossierInfo dossierToDelete) async {
    try {
      // Delete the PDF file
      final pdfFile = File(dossierToDelete.filePath);
      if (await pdfFile.exists()) {
        await pdfFile.delete();
      }

      // Remove the metadata from the JSON file
      final dossiers = await _readDossiers();
      dossiers.removeWhere((d) => d.id == dossierToDelete.id);
      await _writeDossiers(dossiers);
    } catch (e) {
      print('Error deleting dossier: $e');
      rethrow;
    }
  }
}

