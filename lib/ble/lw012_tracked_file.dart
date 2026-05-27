import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persists tracked log to `{appDocuments}/LW012CT/tracked.txt` (native ExportDataActivity).
class Lw012TrackedFile {
  Lw012TrackedFile._();

  static const _folderName = 'LW012CT';
  static const _fileName = 'tracked.txt';

  static Future<File> trackedFile() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}$_folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}${Platform.pathSeparator}$_fileName');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  static Future<void> write(String content) async {
    final file = await trackedFile();
    await file.writeAsString(content);
  }
}
