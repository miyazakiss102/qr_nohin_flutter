import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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

  int confirmedCount = 0;
  bool autoConfirmMode = false;

  final List<QrItem> qrItems = [];

  void addQrCode(String code) {
    final exists = qrItems.any((item) => item.code == code);
    if (exists) {
      return;
    }

    setState(() {
      qrItems.insert(0, QrItem(code: code, isConfirmed: false));

      if (qrItems.length > 20) {
        qrItems.removeLast();
      }
    });
  }

  void confirmAll() {
    setState(() {
      for (final item in qrItems) {
        item.isConfirmed = true;
      }
      confirmedCount = qrItems.where((e) => e.isConfirmed).length;
    });
  }

  void clearAll() {
    setState(() {
      qrItems.clear();
      confirmedCount = 0;
    });
  }

  void toggleAutoConfirm() {
    setState(() {
      autoConfirmMode = !autoConfirmMode;
    });
  }

  void onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;

    bool changed = false;

    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue;

      if (rawValue == null || rawValue.isEmpty) {
        continue;
      }

      final exists = qrItems.any((item) => item.code == rawValue);
      if (exists) {
        continue;
      }

      qrItems.insert(0, QrItem(code: rawValue, isConfirmed: false));

      if (qrItems.length > 20) {
        qrItems.removeLast();
      }

      changed = true;
    }

    if (changed) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double screenWidth = constraints.maxWidth;
            final double screenHeight = constraints.maxHeight;

            final double previewHeight = screenHeight * 0.50;
            final double bottomButtonsHeight = screenHeight * 0.18;
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
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('設定画面は次フェーズで実装します'),
                                ),
                              );
                            },
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
                          fontSize: 30,
                          color: Colors.black87,
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
                        ? const SizedBox()
                        : GridView.builder(
                            itemCount: qrItems.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 4.8,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemBuilder: (context, index) {
                              final item = qrItems[index];

                              return Container(
                                alignment: Alignment.centerLeft,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
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
                                child: Text(
                                  item.code,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),

                SizedBox(
                  height: bottomButtonsHeight + 52,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: confirmWidth,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 8, right: 8),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 42,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('出力履歴は次フェーズ以降で実装します'),
                                        ),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.black,
                                      backgroundColor: Colors.white,
                                    ),
                                    child: const Text(
                                      '出力履歴',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                height: bottomButtonsHeight,
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
                                    style: TextStyle(fontSize: 22),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: 8,
                              right: 8,
                              bottom: 0,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 63,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('確認画面は次フェーズ以降で実装します'),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade300,
                                        foregroundColor: Colors.black,
                                      ),
                                      child: const Text(
                                        '確認',
                                        style: TextStyle(fontSize: 18),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 101,
                                  height: 62,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('TXT出力は次フェーズ以降で実装します'),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade300,
                                      foregroundColor: Colors.black,
                                    ),
                                    child: const Text(
                                      '出力',
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 71,
                                  height: 59,
                                  child: ElevatedButton(
                                    onPressed: clearAll,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange.shade300,
                                      foregroundColor: Colors.black,
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: const Text(
                                      'クリア',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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

class QrItem {
  final String code;
  bool isConfirmed;

  QrItem({
    required this.code,
    required this.isConfirmed,
  });
}