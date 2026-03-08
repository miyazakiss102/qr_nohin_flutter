import 'package:flutter/material.dart';

import 'pages/scanner_page.dart';

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
      home: ScannerPage(),
    );
  }
}
