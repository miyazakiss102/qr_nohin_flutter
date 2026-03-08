import 'package:flutter/material.dart';

class OverlayBoxData {
  final Rect rect;
  final String code;
  final bool isConfirmed;
  final int? confirmedNo;

  OverlayBoxData({
    required this.rect,
    required this.code,
    required this.isConfirmed,
    required this.confirmedNo,
  });

  OverlayBoxData copyWith({
    Rect? rect,
    String? code,
    bool? isConfirmed,
    int? confirmedNo,
  }) {
    return OverlayBoxData(
      rect: rect ?? this.rect,
      code: code ?? this.code,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      confirmedNo: confirmedNo ?? this.confirmedNo,
    );
  }
}
