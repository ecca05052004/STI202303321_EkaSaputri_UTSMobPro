import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileHelper {
  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/data_journal.json');
  }

  static Future<List<Map<String, dynamic>>> readNotes() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        final data = json.decode(contents);
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveNotes(List<Map<String, dynamic>> notes) async {
    final file = await _localFile;
    final data = json.encode(notes);
    await file.writeAsString(data);
  }
}
