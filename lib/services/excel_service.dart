import 'package:flutter/services.dart' show rootBundle;
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ExcelService {
  Future<Excel?> loadNavLogTemplate() async {
    try {
      // 1. Load the template from assets
      final byteData = await rootBundle.load('assets/templates/Log PND03.xlsx');
      final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);

      // 2. Get a temporary directory to work with the file
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/temp_nav_log.xlsx';

      // 3. Write the asset to the temporary file
      await File(tempPath).writeAsBytes(bytes, flush: true);

      // 4. Read the Excel file from the temporary path
      final excelBytes = File(tempPath).readAsBytesSync();
      final excel = Excel.decodeBytes(excelBytes);

      return excel;
    } catch (e) {
      print('Error loading Excel template: $e');
      return null;
    }
  }

  // We will add methods for saving/updating the file later.
}
