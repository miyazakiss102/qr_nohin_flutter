class HistoryEntry {
  final String exportId;
  final DateTime exportedAt;
  final int confirmedNo;
  final String fullCode;
  final String code12;

  const HistoryEntry({
    required this.exportId,
    required this.exportedAt,
    required this.confirmedNo,
    required this.fullCode,
    required this.code12,
  });

  String get shipNo {
    if (fullCode.length < 5) return '';
    return fullCode.substring(0, 5);
  }

  String get area {
    if (fullCode.length < 14) return '';
    return fullCode.substring(12, 14);
  }

  String get block {
    if (fullCode.length < 18) return '';
    return fullCode.substring(14, 18);
  }

  String get exportDateKey {
    final y = exportedAt.year.toString().padLeft(4, '0');
    final m = exportedAt.month.toString().padLeft(2, '0');
    final d = exportedAt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Map<String, dynamic> toJson() {
    return {
      'exportId': exportId,
      'exportedAt': exportedAt.toIso8601String(),
      'confirmedNo': confirmedNo,
      'fullCode': fullCode,
      'code12': code12,
    };
  }

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      exportId: json['exportId'] as String,
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      confirmedNo: json['confirmedNo'] as int,
      fullCode: json['fullCode'] as String,
      code12: json['code12'] as String,
    );
  }
}
