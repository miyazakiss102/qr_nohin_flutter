import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class NohinExportService {
  static final DateFormat _folderFormatter = DateFormat('yyyyMMdd');
  static final DateFormat _fileFormatter = DateFormat('yyyyMMdd_HHmmss');

  static String buildTodayFolderName(DateTime baseDate) {
    return _folderFormatter.format(baseDate);
  }

  static String buildFileName(DateTime baseDate) {
    return 'nohin_${_fileFormatter.format(baseDate)}.txt';
  }

  static bool isNohinFormat(String normalized) {
    if (normalized.length < 12) return false;

    final first5 = normalized.substring(0, 5);
    final next7 = normalized.substring(5, 12);

    final first5Ok = RegExp(r'^\d{5}$').hasMatch(first5);
    final next7Ok = RegExp(r'^[0-9A-Z]{7}$').hasMatch(next7);

    return first5Ok && next7Ok;
  }

  static Future<Directory> getBaseSaveDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final saveDir = Directory('${dir.path}/nohin_txt');

    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    return saveDir;
  }

  static Future<File> saveTxt({
    required String content,
    required DateTime baseDate,
  }) async {
    final rootFolder = await getBaseSaveDirectory();

    final todayFolderName = buildTodayFolderName(baseDate);
    final todayFolder = Directory('${rootFolder.path}/$todayFolderName');

    if (!await todayFolder.exists()) {
      await todayFolder.create(recursive: true);
    }

    final fileName = buildFileName(baseDate);
    final file = File('${todayFolder.path}/$fileName');

    await file.writeAsString(content, flush: true);
    return file;
  }

  static Future<void> shareFile(File file) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'QR読み込み結果TXT',
        title: 'QR読み込み結果TXT',
      ),
    );
  }
}
