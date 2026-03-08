import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';

void main() {
  runApp(const QrNohinApp());
}

class QrNohinApp extends StatelessWidget {
  const QrNohinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR納品',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const ScannerPage(),
    );
  }
}

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

  final List<QrItem> qrItems = [];
  final Set<String> scannedCodeSet = {};

  int nextSequence = 1;
  DateTime? lastDuplicateNoticeAt;

  int get confirmedCount {
    return qrItems.where((item) => item.isConfirmed).length;
  }

  int get totalCount {
    return qrItems.length;
  }

  Future<void> showToastMessage(String message) async {
    await Fluttertoast.cancel();
    await Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  Future<void> notifyDuplicateIfNeeded() async {
    final now = DateTime.now();

    if (lastDuplicateNoticeAt != null &&
        now.difference(lastDuplicateNoticeAt!) <
            const Duration(seconds: 2)) {
      return;
    }

    lastDuplicateNoticeAt = now;

    if (duplicateVibrationEnabled) {
      final bool? canVibrate = await Vibration.hasVibrator();
      if (canVibrate ?? false) {
        await Vibration.vibrate(duration: 80);
      }
    }

    await showToastMessage('読み込み済みです');
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

  void addQrCode(String rawCode) {
    final String code = rawCode.trim();

    if (code.isEmpty) {
      return;
    }

    if (scannedCodeSet.contains(code)) {
      notifyDuplicateIfNeeded();
      return;
    }

    setState(() {
      scannedCodeSet.add(code);

      qrItems.add(
        QrItem(
          sequenceNo: nextSequence,
          code: code,
          isConfirmed: autoConfirmMode,
        ),
      );

      nextSequence++;

      
    });

    scrollListToBottom();
  }

  void confirmAll() {
    setState(() {
      for (final item in qrItems) {
        item.isConfirmed = true;
      }
    });
  }

  void clearAll() {
    setState(() {
      qrItems.clear();
      scannedCodeSet.clear();
      nextSequence = 1;
    });
  }

  void toggleAutoConfirm() {
    setState(() {
      autoConfirmMode = !autoConfirmMode;
    });
  }

  void onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;

    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.isEmpty) {
        continue;
      }

      addQrCode(rawValue);
    }
  }

  Future<void> openSettings() async {
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          duplicateVibrationEnabled: duplicateVibrationEnabled,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      duplicateVibrationEnabled = result;
    });
  }

  @override
  void dispose() {
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
                          onDetect: onDetect,
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
                        '件数: $totalCount',
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '確定: $confirmedCount',
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
                    child: qrItems.isEmpty
                        ? const Center(
                            child: Text(
                              'QRデータはまだありません',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.black54,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: listScrollController,
                            itemCount: qrItems.length,
                            itemBuilder: (context, index) {
                              final item = qrItems[index];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: item.isConfirmed
                                      ? Colors.red.shade100
                                      : Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: item.isConfirmed
                                        ? Colors.red
                                        : Colors.green,
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        '${item.sequenceNo}',
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
                            onPressed: confirmAll,
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
                                    showToastMessage('出力履歴は次フェーズで実装します');
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
                                            showToastMessage('確認画面は次フェーズ以降で実装します');
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
                                          showToastMessage('TXT出力は次フェーズ以降で実装します');
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.grey.shade300,
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

class SettingsPage extends StatefulWidget {
  final bool duplicateVibrationEnabled;

  const SettingsPage({
    super.key,
    required this.duplicateVibrationEnabled,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool tempDuplicateVibrationEnabled;

  @override
  void initState() {
    super.initState();
    tempDuplicateVibrationEnabled = widget.duplicateVibrationEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('重複読取時の振動通知'),
            subtitle: const Text('同じQRを読み込んだときに振動させる'),
            value: tempDuplicateVibrationEnabled,
            onChanged: (value) {
              setState(() {
                tempDuplicateVibrationEnabled = value;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, tempDuplicateVibrationEnabled);
                },
                child: const Text('保存して戻る'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QrItem {
  final int sequenceNo;
  final String code;
  bool isConfirmed;

  QrItem({
    required this.sequenceNo,
    required this.code,
    required this.isConfirmed,
  });
}