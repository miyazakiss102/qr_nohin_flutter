import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/history_entry.dart';

class HistoryService {
  static const String _fileName = 'history_entries.json';

  static Future<File> _getHistoryFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<List<HistoryEntry>> loadEntries() async {
    try {
      final file = await _getHistoryFile();

      if (!await file.exists()) {
        return [];
      }

      final text = await file.readAsString();
      if (text.trim().isEmpty) {
        return [];
      }

      final list = jsonDecode(text) as List<dynamic>;
      return list
          .map((e) => HistoryEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveEntries(List<HistoryEntry> entries) async {
    final file = await _getHistoryFile();
    final jsonText = jsonEncode(entries.map((e) => e.toJson()).toList());
    await file.writeAsString(jsonText, flush: true);
  }

  static Future<void> appendExport({
    required String exportId,
    required DateTime exportedAt,
    required List<HistoryEntry> newEntries,
  }) async {
    final current = await loadEntries();
    current.addAll(newEntries);
    await saveEntries(current);
  }

  static Future<void> deleteExport(String exportId) async {
    final current = await loadEntries();
    final filtered = current.where((e) => e.exportId != exportId).toList();
    await saveEntries(filtered);
  }
}
