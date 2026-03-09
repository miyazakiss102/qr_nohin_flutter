import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/nohin_export_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}

class HistoryFileRecord {
  final String fullCode;
  final int lineIndex;

  const HistoryFileRecord({required this.fullCode, required this.lineIndex});

  // 1～5カラム
  String get shipNo {
    if (fullCode.length < 5) return '';
    return fullCode.substring(0, 5);
  }

  // 13～14カラム
  String get area {
    if (fullCode.length < 14) return '';
    return fullCode.substring(12, 14);
  }

  // 15～18カラム
  String get block {
    if (fullCode.length < 18) return '';
    return fullCode.substring(14, 18);
  }
}

class HistoryFileItem {
  final File file;
  final DateTime exportedAt;
  final List<HistoryFileRecord> records;

  const HistoryFileItem({
    required this.file,
    required this.exportedAt,
    required this.records,
  });

  String get fileName => file.uri.pathSegments.last;

  String get exportDateKey {
    final y = exportedAt.year.toString().padLeft(4, '0');
    final m = exportedAt.month.toString().padLeft(2, '0');
    final d = exportedAt.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }
}

class LatestRecordRef {
  final DateTime exportedAt;
  final String filePath;
  final int lineIndex;

  const LatestRecordRef({
    required this.exportedAt,
    required this.filePath,
    required this.lineIndex,
  });
}

class _HistoryPageState extends State<HistoryPage> {
  static const String _prefShowLatestOnlyKey =
      'history_show_latest_only_for_duplicates';

  bool isLoading = true;

  final TextEditingController shipNoController = TextEditingController();
  final TextEditingController areaController = TextEditingController();
  final TextEditingController blockController = TextEditingController();

  String shipNoKeyword = '';
  String areaKeyword = '';
  String blockKeyword = '';

  bool showLatestOnlyForDuplicates = false;

  List<HistoryFileItem> allItems = [];

  @override
  void initState() {
    super.initState();
    loadPreferences();
    loadHistory();
  }

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedValue = prefs.getBool(_prefShowLatestOnlyKey) ?? false;

    if (!mounted) return;

    setState(() {
      showLatestOnlyForDuplicates = savedValue;
    });
  }

  Future<void> saveShowLatestOnlyPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefShowLatestOnlyKey, value);
  }

  @override
  void dispose() {
    shipNoController.dispose();
    areaController.dispose();
    blockController.dispose();
    super.dispose();
  }

  Future<void> loadHistory() async {
    setState(() {
      isLoading = true;
    });

    try {
      final baseDir = await NohinExportService.getBaseSaveDirectory();

      if (!await baseDir.exists()) {
        setState(() {
          allItems = [];
          isLoading = false;
        });
        return;
      }

      final List<File> txtFiles = [];
      final dateFolders = baseDir.listSync().whereType<Directory>().toList();

      for (final folder in dateFolders) {
        final files = folder
            .listSync()
            .whereType<File>()
            .where((file) => file.path.toLowerCase().endsWith('.txt'))
            .toList();

        txtFiles.addAll(files);
      }

      final List<HistoryFileItem> loadedItems = [];

      for (final file in txtFiles) {
        final stat = await file.stat();
        final text = await file.readAsString();

        final lines = text
            .split(RegExp(r'\r?\n'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        final records = lines.asMap().entries.map((entry) {
          return HistoryFileRecord(fullCode: entry.value, lineIndex: entry.key);
        }).toList();

        loadedItems.add(
          HistoryFileItem(
            file: file,
            exportedAt: stat.modified,
            records: records,
          ),
        );
      }

      loadedItems.sort((a, b) => b.exportedAt.compareTo(a.exportedAt));

      if (!mounted) return;

      setState(() {
        allItems = loadedItems;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        allItems = [];
        isLoading = false;
      });
    }
  }

  Future<void> shareFile(File file) async {
    try {
      await NohinExportService.shareFile(file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('共有に失敗しました')));
    }
  }

  Future<void> deleteFile(HistoryFileItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('削除確認'),
          content: Text('${item.fileName} を削除しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (ok != true) {
      return;
    }

    try {
      await item.file.delete();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('削除しました')));

      await loadHistory();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('削除に失敗しました')));
    }
  }

  bool containsIgnoreCase(String source, String keyword) {
    return source.toUpperCase().contains(keyword.trim().toUpperCase());
  }

  bool recordMatches(HistoryFileRecord record) {
    final shipNoKey = shipNoKeyword.trim();
    final areaKey = areaKeyword.trim();
    final blockKey = blockKeyword.trim();

    final shipNoOk =
        shipNoKey.isEmpty || containsIgnoreCase(record.shipNo, shipNoKey);

    final areaOk = areaKey.isEmpty || containsIgnoreCase(record.area, areaKey);

    final blockOk =
        blockKey.isEmpty || containsIgnoreCase(record.block, blockKey);

    return shipNoOk && areaOk && blockOk;
  }

  List<HistoryFileItem> buildFilteredItems() {
    final noFilter =
        shipNoKeyword.trim().isEmpty &&
        areaKeyword.trim().isEmpty &&
        blockKeyword.trim().isEmpty;

    if (noFilter) {
      return allItems;
    }

    final List<HistoryFileItem> result = [];

    for (final item in allItems) {
      final matchedRecords = item.records.where(recordMatches).toList();

      if (matchedRecords.isNotEmpty) {
        result.add(
          HistoryFileItem(
            file: item.file,
            exportedAt: item.exportedAt,
            records: matchedRecords,
          ),
        );
      }
    }

    return result;
  }

  Map<String, List<HistoryFileItem>> buildGroupedItems(
    List<HistoryFileItem> items,
  ) {
    final Map<String, List<HistoryFileItem>> grouped = {};

    for (final item in items) {
      grouped.putIfAbsent(item.exportDateKey, () => []);
      grouped[item.exportDateKey]!.add(item);
    }

    return grouped;
  }

  Map<String, int> buildDuplicateCountMapAll(List<HistoryFileItem> items) {
    final Map<String, int> counts = {};

    for (final item in items) {
      for (final record in item.records) {
        counts[record.fullCode] = (counts[record.fullCode] ?? 0) + 1;
      }
    }

    return counts;
  }

  bool isNewerRecordRef(LatestRecordRef current, LatestRecordRef candidate) {
    final timeCompare = candidate.exportedAt.compareTo(current.exportedAt);
    if (timeCompare != 0) {
      return timeCompare > 0;
    }

    final fileCompare = candidate.filePath.compareTo(current.filePath);
    if (fileCompare != 0) {
      return fileCompare > 0;
    }

    return candidate.lineIndex > current.lineIndex;
  }

  Map<String, LatestRecordRef> buildLatestRecordMapAll(
    List<HistoryFileItem> items,
  ) {
    final Map<String, LatestRecordRef> latestMap = {};

    for (final item in items) {
      for (final record in item.records) {
        final candidate = LatestRecordRef(
          exportedAt: item.exportedAt,
          filePath: item.file.path,
          lineIndex: record.lineIndex,
        );

        final current = latestMap[record.fullCode];
        if (current == null || isNewerRecordRef(current, candidate)) {
          latestMap[record.fullCode] = candidate;
        }
      }
    }

    return latestMap;
  }

  bool isLatestRecordAll({
    required HistoryFileItem item,
    required HistoryFileRecord record,
    required Map<String, LatestRecordRef> latestMap,
  }) {
    final latest = latestMap[record.fullCode];
    if (latest == null) return true;

    return latest.filePath == item.file.path &&
        latest.lineIndex == record.lineIndex &&
        latest.exportedAt == item.exportedAt;
  }

  List<HistoryFileItem> buildDisplayItems(
    List<HistoryFileItem> items,
    Map<String, LatestRecordRef> latestMap,
  ) {
    if (!showLatestOnlyForDuplicates) {
      return items;
    }

    final List<HistoryFileItem> result = [];

    for (final item in items) {
      final visibleRecords = item.records.where((record) {
        return isLatestRecordAll(
          item: item,
          record: record,
          latestMap: latestMap,
        );
      }).toList();

      if (visibleRecords.isNotEmpty) {
        result.add(
          HistoryFileItem(
            file: item.file,
            exportedAt: item.exportedAt,
            records: visibleRecords,
          ),
        );
      }
    }

    return result;
  }

  void clearSearch() {
    shipNoController.clear();
    areaController.clear();
    blockController.clear();

    setState(() {
      shipNoKeyword = '';
      areaKeyword = '';
      blockKeyword = '';
    });
  }

  Widget buildSearchField({
    required TextEditingController controller,
    required String label,
    required int maxLength,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9a-zA-Z]')),
        UpperCaseTextFormatter(),
        LengthLimitingTextInputFormatter(maxLength),
      ],
      onChanged: (value) {
        final upper = value.toUpperCase();
        if (controller.text != upper) {
          controller.value = controller.value.copyWith(
            text: upper,
            selection: TextSelection.collapsed(offset: upper.length),
            composing: TextRange.empty,
          );
        }
        onChanged(upper);
      },
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(Icons.clear),
              ),
      ),
    );
  }

  String formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$y/$m/$d $hh:$mm:$ss';
  }

  Map<String, Map<String, int>> buildDuplicateDateMapAll(
    List<HistoryFileItem> items,
  ) {
    final Map<String, Map<String, int>> result = {};

    for (final item in items) {
      for (final record in item.records) {
        result.putIfAbsent(record.fullCode, () => {});
        result[record.fullCode]!.update(
          item.exportDateKey,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }

    return result;
  }

  Future<void> showDuplicateDatesDialog({
    required String fullCode,
    required Map<String, int> dateCountMap,
  }) async {
    final sortedKeys = dateCountMap.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重複日一覧'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  fullCode,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...sortedKeys.map((dateKey) {
                  final count = dateCountMap[dateKey] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '$dateKey（$count件）',
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = buildFilteredItems();
    final duplicateMapAll = buildDuplicateCountMapAll(filteredItems);
    final duplicateDateMapAll = buildDuplicateDateMapAll(filteredItems);
    final latestMapAll = buildLatestRecordMapAll(filteredItems);
    final displayItems = buildDisplayItems(filteredItems, latestMapAll);

    final groupedItems = buildGroupedItems(displayItems);
    final sortedDateKeys = groupedItems.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '出力履歴',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: loadHistory,
            icon: const Icon(Icons.refresh),
            tooltip: '再読込',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              children: [
                buildSearchField(
                  controller: shipNoController,
                  label: '番船（部分一致）',
                  maxLength: 5,
                  onChanged: (value) {
                    setState(() {
                      shipNoKeyword = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                buildSearchField(
                  controller: areaController,
                  label: '区画（部分一致）',
                  maxLength: 2,
                  onChanged: (value) {
                    setState(() {
                      areaKeyword = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                buildSearchField(
                  controller: blockController,
                  label: 'ブロック（部分一致）',
                  maxLength: 4,
                  onChanged: (value) {
                    setState(() {
                      blockKeyword = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.filter_alt_outlined, size: 18),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        '番船・区画・ブロックはAND条件で検索',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                    TextButton(
                      onPressed: clearSearch,
                      child: const Text('クリア'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '重複は最新のみ表示',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Switch(
                        value: showLatestOnlyForDuplicates,
                        onChanged: (value) async {
                          setState(() {
                            showLatestOnlyForDuplicates = value;
                          });
                          await saveShowLatestOnlyPreference(value);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : sortedDateKeys.isEmpty
                ? const Center(
                    child: Text(
                      '該当する履歴はありません',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  )
                : ListView.builder(
                    itemCount: sortedDateKeys.length,
                    itemBuilder: (context, index) {
                      final dateKey = sortedDateKeys[index];
                      final items = groupedItems[dateKey]!;

                      return Card(
                        margin: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          title: Row(
                            children: [
                              Text(
                                dateKey,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const Spacer(),

                              Text(
                                '${items.fold<int>(0, (sum, e) => sum + e.records.length)}',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          children: items.map((item) {
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ExpansionTile(
                                title: Text(
                                  item.fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  '${formatDateTime(item.exportedAt)}  /  ${item.records.length}件',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${item.records.length}',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      onPressed: () => shareFile(item.file),
                                      icon: const Icon(Icons.share),
                                      tooltip: '再共有',
                                    ),
                                    IconButton(
                                      onPressed: () => deleteFile(item),
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: '削除',
                                    ),
                                  ],
                                ),
                                children: item.records.map((record) {
                                  final totalCount =
                                      duplicateMapAll[record.fullCode] ?? 0;
                                  final duplicateOtherCount = totalCount >= 2
                                      ? totalCount - 1
                                      : 0;
                                  final showDuplicateLabel =
                                      !showLatestOnlyForDuplicates &&
                                      duplicateOtherCount >= 1;

                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      6,
                                      12,
                                      6,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.black12,
                                        ),
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: showDuplicateLabel
                                            ? () async {
                                                final dateCountMap =
                                                    duplicateDateMapAll[record
                                                        .fullCode];
                                                if (dateCountMap == null ||
                                                    dateCountMap.isEmpty) {
                                                  return;
                                                }

                                                await showDuplicateDatesDialog(
                                                  fullCode: record.fullCode,
                                                  dateCountMap: dateCountMap,
                                                );
                                              }
                                            : null,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 10,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              if (showDuplicateLabel) ...[
                                                Text(
                                                  '重複$duplicateOtherCount件',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.red.shade700,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              Expanded(
                                                child: SelectableText(
                                                  record.fullCode,
                                                  maxLines: 1,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    height: 1.2,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
