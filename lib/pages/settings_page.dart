import 'package:flutter/material.dart';
import '../models/settings_result.dart';

class SettingsPage extends StatefulWidget {
  final bool duplicateVibrationEnabled;
  final bool overlayEnabled;

  const SettingsPage({
    super.key,
    required this.duplicateVibrationEnabled,
    required this.overlayEnabled,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool tempDuplicateVibrationEnabled;
  late bool tempOverlayEnabled;

  @override
  void initState() {
    super.initState();
    tempDuplicateVibrationEnabled = widget.duplicateVibrationEnabled;
    tempOverlayEnabled = widget.overlayEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
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
          SwitchListTile(
            title: const Text('QR追従オーバーレイ'),
            subtitle: const Text('QR位置に枠と番号を表示する'),
            value: tempOverlayEnabled,
            onChanged: (value) {
              setState(() {
                tempOverlayEnabled = value;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    SettingsResult(
                      duplicateVibrationEnabled: tempDuplicateVibrationEnabled,
                      overlayEnabled: tempOverlayEnabled,
                    ),
                  );
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
