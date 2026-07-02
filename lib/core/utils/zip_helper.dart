import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

class ZipHelper {
  /// Zips a map of [filesToZip] (mapping entry name in zip to the File on disk)
  /// and writes the output to [zipFilePath].
  static Future<File> createZip({
    required String zipFilePath,
    required Map<String, File> filesToZip,
  }) async {
    debugPrint('ZipHelper: Starting ZIP creation at $zipFilePath');
    final archive = Archive();

    for (final entry in filesToZip.entries) {
      final targetName = entry.key;
      final file = entry.value;
      final exists = file.path.startsWith('simulated_') ? true : await file.exists();
      
      debugPrint('ZipHelper: Adding file "$targetName" from path "${file.path}" (exists: $exists)');

      List<int> bytes;
      if (file.path.startsWith('simulated_')) {
        bytes = utf8.encode('Simulated binary content for $targetName');
      } else if (await file.exists()) {
        bytes = await file.readAsBytes();
      } else {
        debugPrint('ZipHelper: WARNING - File "$targetName" at path "${file.path}" does not exist and was skipped!');
        continue;
      }
      
      archive.addFile(ArchiveFile(targetName, bytes.length, bytes));
    }

    final zipData = ZipEncoder().encode(archive);
    final zipFile = File(zipFilePath);
    await zipFile.writeAsBytes(zipData);
    
    debugPrint('ZipHelper: ZIP creation completed successfully.');
    return zipFile;
  }
}
