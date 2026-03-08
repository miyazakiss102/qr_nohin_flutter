import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';

import '../models/confirmed_qr_item.dart';
import '../models/overlay_box_data.dart';
import '../models/settings_result.dart';
import '../widgets/overlay_layer.dart';
import 'settings_page.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController controller = MobileScannerController();
  final ScrollController listScrollController = ScrollController();

  bool autoConfirmMode = false;
  bool duplicateVibrationEnabled = true;
  bool overlayEnabled = true;

  final List<ConfirmedQrItem> confirmedItems = [];
  final Set<String> confirmedCodeSet = {};
  final Map<String, DateTime> recentConfirmedAtMap = {};
  final Map<String, OverlayBoxData> overlayMap = {};
  final Map<String, Timer> duplicateHighlightTimers = {};

  List<String> currentVisibleCodes = [];
  int nextConfirmedSequence = 1;
  DateTime? lastDuplicateNoticeAt;
  Timer? overlayClearTimer;

  int get confirmedCount => confirmedItems.length;
  void highlightDuplicateItem(String code) {
    final index = confirmedItems.indexWhere((item) => item.code == code);
    if (index == -1) {
      return;
    }

    duplicateHighlightTimers[code]?.cancel();

    setState(() {
      confirmedItems[index] = confirmedItems[index].copyWith(
        isDuplicateHighlighted: true,
      );
    });

    duplicateHighlightTimers[code] = Timer(const Duration(seconds: 10), () {
      if (!mounted) {
        return;
      }

      final resetIndex = confirmedItems.indexWhere((item) => item.code == code);
      if (resetIndex == -1) {
        return;
      }

      setState(() {
        confirmedItems[resetIndex] = confirmedItems[resetIndex].copyWith(
          isDuplicateHighlighted: false,
        );
      });
    });
  }

  ConfirmedQrItem? findConfirmedItemByCode(String code) {
    for (final item in confirmedItems) {
      if (item.code == code) {
        return item;
      }
    }
    return null;
  }

  Future<void> showToastMessage(String message) async {
    await Fluttertoast.cancel();
    await Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  Future<void> notifyDuplicateIfNeeded(String code) async {
    final now = DateTime.now();

    final recentConfirmedAt = recentConfirmedAtMap[code];
    if (recentConfirmedAt != null &&
        now.difference(recentConfirmedAt) < const Duration(seconds: 2)) {
      return;
    }

    highlightDuplicateItem(code);

    if (lastDuplicateNoticeAt != null &&
        now.difference(lastDuplicateNoticeAt!) < const Duration(seconds: 2)) {
      return;
    }

    lastDuplicateNoticeAt = now;

    if (duplicateVibrationEnabled) {
      final bool? canVibrate = await Vibration.hasVibrator();
      if (canVibrate ?? false) {
        await Vibration.vibrate(duration: 80);
      }
    }

    await showToastMessage('読み込み済です');
  }

  void scrollListToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!listScrollController.hasClients) {
        return;
      }

      listScrollController.animateTo(
        listScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void clearOverlaySoon() {
    overlayClearTimer?.cancel();
    overlayClearTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }

      setState(() {
        overlayMap.clear();
        currentVisibleCodes = [];
      });
    });
  }

  void confirmCode(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      return;
    }

    if (confirmedCodeSet.contains(trimmed)) {
      return;
    }

    confirmedCodeSet.add(trimmed);

    confirmedItems.add(
      ConfirmedQrItem(
        confirmedNo: nextConfirmedSequence,
        code: trimmed,
        isDuplicateHighlighted: true, // ←最初は赤
      ),
    );

    recentConfirmedAtMap[trimmed] = DateTime.now();
    nextConfirmedSequence++;

    // 10秒後に緑へ戻す
    highlightDuplicateItem(trimmed);
  }

  void confirmCurrentVisibleCodes() {
    if (currentVisibleCodes.isEmpty) {
      return;
    }

    bool changed = false;

    setState(() {
      for (final code in currentVisibleCodes) {
        if (confirmedCodeSet.contains(code)) {
          continue;
        }

        confirmCode(code);
        changed = true;
      }

      for (final code in overlayMap.keys) {
        final confirmedItem = findConfirmedItemByCode(code);
        if (confirmedItem == null) {
          continue;
        }

        final old = overlayMap[code];
        if (old == null) {
          continue;
        }

        overlayMap[code] = old.copyWith(
          isConfirmed: true,
          confirmedNo: confirmedItem.confirmedNo,
        );
      }
    });

    if (changed) {
      scrollListToBottom();
    }
  }

  void clearAll() {
    for (final timer in duplicateHighlightTimers.values) {
      timer.cancel();
    }
    duplicateHighlightTimers.clear();

    setState(() {
      confirmedItems.clear();
      confirmedCodeSet.clear();
      recentConfirmedAtMap.clear();
      overlayMap.clear();
      currentVisibleCodes = [];
      nextConfirmedSequence = 1;
      lastDuplicateNoticeAt = null;
    });
  }

  void toggleAutoConfirm() {
    setState(() {
      autoConfirmMode = !autoConfirmMode;
    });
  }

  Rect? buildRectFromBarcode(
    Barcode barcode,
    Size previewWidgetSize,
    Size captureSize,
  ) {
    final corners = barcode.corners;
    if (corners.isEmpty) {
      return null;
    }

    double minX = corners.first.dx;
    double minY = corners.first.dy;
    double maxX = corners.first.dx;
    double maxY = corners.first.dy;

    for (final p in corners) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }

    if (captureSize.width <= 0 || captureSize.height <= 0) {
      return null;
    }

    final scaleX = previewWidgetSize.width / captureSize.width;
    final scaleY = previewWidgetSize.height / captureSize.height;

    final left = minX * scaleX;
    final top = minY * scaleY;
    final right = maxX * scaleX;
    final bottom = maxY * scaleY;

    return Rect.fromLTRB(left, top, right, bottom);
  }

  void onDetect(BarcodeCapture capture, Size previewWidgetSize) {
    overlayClearTimer?.cancel();

    final captureSize = Size(
      capture.size.width.toDouble(),
      capture.size.height.toDouble(),
    );

    final Map<String, OverlayBoxData> newOverlayMap = {};
    final List<String> newVisibleCodes = [];
    final List<String> codesToAutoConfirm = [];

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue?.trim();
      if (rawValue == null || rawValue.isEmpty) {
        continue;
      }

      if (!newVisibleCodes.contains(rawValue)) {
        newVisibleCodes.add(rawValue);
      }

      final rect = buildRectFromBarcode(
        barcode,
        previewWidgetSize,
        captureSize,
      );

      if (rect == null) {
        continue;
      }

      final confirmedItem = findConfirmedItemByCode(rawValue);
      final isConfirmed = confirmedItem != null;

      newOverlayMap[rawValue] = OverlayBoxData(
        rect: rect,
        code: rawValue,
        isConfirmed: isConfirmed,
        confirmedNo: confirmedItem?.confirmedNo,
      );

      if (autoConfirmMode && !isConfirmed) {
        codesToAutoConfirm.add(rawValue);
      }

      if (isConfirmed) {
        notifyDuplicateIfNeeded(rawValue);
      }
    }

    if (autoConfirmMode && codesToAutoConfirm.isNotEmpty) {
      for (final code in codesToAutoConfirm) {
        if (confirmedCodeSet.contains(code)) {
          continue;
        }
        confirmCode(code);
      }

      for (final code in newOverlayMap.keys) {
        final confirmedItem = findConfirmedItemByCode(code);
        if (confirmedItem == null) {
          continue;
        }

        final old = newOverlayMap[code];
        if (old == null) {
          continue;
        }

        newOverlayMap[code] = old.copyWith(
          isConfirmed: true,
          confirmedNo: confirmedItem.confirmedNo,
        );
      }

      scrollListToBottom();
    }

    setState(() {
      currentVisibleCodes = newVisibleCodes;
      overlayMap
        ..clear()
        ..addAll(newOverlayMap);
    });

    clearOverlaySoon();
  }

  Future<void> openSettings() async {
    final result = await Navigator.push<SettingsResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          duplicateVibrationEnabled: duplicateVibrationEnabled,
          overlayEnabled: overlayEnabled,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      duplicateVibrationEnabled = result.duplicateVibrationEnabled;
      overlayEnabled = result.overlayEnabled;
    });
  }

  @override
  void dispose() {
    overlayClearTimer?.cancel();

    for (final timer in duplicateHighlightTimers.values) {
      timer.cancel();
    }
    duplicateHighlightTimers.clear();

    controller.dispose();
    listScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double screenWidth = constraints.maxWidth;
            final double previewHeight = screenWidth * 1.0;
            const double bottomAreaHeight = 92;
            final double confirmWidth = screenWidth * 0.33;
            final Size previewSize = Size(screenWidth, previewHeight);

            return Column(
              children: [
                SizedBox(
                  height: previewHeight,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: MobileScanner(
                          controller: controller,
                          onDetect: (capture) => onDetect(capture, previewSize),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: SafeArea(
                          bottom: false,
                          child: TopConfirmedOverlay(
                            confirmedItems: confirmedItems,
                          ),
                        ),
                      ),
                      if (overlayEnabled)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: OverlayLayer(
                              overlayItems: overlayMap.values.toList(),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: SizedBox(
                          width: 82,
                          height: 40,
                          child: ElevatedButton(
                            onPressed: openSettings,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.black,
                              elevation: 1,
                              padding: EdgeInsets.zero,
                            ),
                            child: const Text(
                              '設定',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8, top: 4),
                  child: Row(
                    children: [
                      Text(
                        '確定件数: $confirmedCount',
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '自動確定: ${autoConfirmMode ? "ON" : "OFF"}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: confirmedItems.isEmpty
                        ? const Center(
                            child: Text(
                              '確定データはまだありません',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.black54,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: listScrollController,
                            itemCount: confirmedItems.length,
                            itemBuilder: (context, index) {
                              final item = confirmedItems[index];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.black26,
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        '${item.confirmedNo}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      '.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item.code,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
                SizedBox(
                  height: bottomAreaHeight + 22,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: confirmWidth,
                          child: ElevatedButton(
                            onPressed: confirmCurrentVisibleCodes,
                            onLongPress: toggleAutoConfirm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                            ),
                            child: const Text(
                              '確定\n（長押し:自動）',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 28,
                                child: OutlinedButton(
                                  onPressed: () {
                                    showToastMessage('出力履歴は次フェーズ以降で実装します');
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.black,
                                    backgroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Text(
                                    '出力履歴',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            showToastMessage(
                                              '確認画面は次フェーズ以降で実装します',
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.grey.shade300,
                                            foregroundColor: Colors.black,
                                          ),
                                          child: const Text(
                                            '確認',
                                            style: TextStyle(fontSize: 15),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 101,
                                      height: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          showToastMessage(
                                            'TXT出力は次フェーズ以降で実装します',
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey.shade300,
                                          foregroundColor: Colors.black,
                                        ),
                                        child: const Text(
                                          '出力',
                                          style: TextStyle(fontSize: 15),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 71,
                                      height: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: clearAll,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.orange.shade300,
                                          foregroundColor: Colors.black,
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: const Text(
                                          'クリア',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class TopConfirmedOverlay extends StatelessWidget {
  final List<ConfirmedQrItem> confirmedItems;

  const TopConfirmedOverlay({super.key, required this.confirmedItems});

  @override
  Widget build(BuildContext context) {
    if (confirmedItems.isEmpty) {
      return const SizedBox();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: confirmedItems.map((item) {
          final bool isRed = item.isDuplicateHighlighted;

          return Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isRed
                  ? Colors.red.withOpacity(0.92)
                  : Colors.green.withOpacity(0.90),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: Text(
              '${item.confirmedNo}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
