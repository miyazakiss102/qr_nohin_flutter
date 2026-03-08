class ConfirmedQrItem {
  final int confirmedNo;
  final String code;
  final bool isDuplicateHighlighted;

  ConfirmedQrItem({
    required this.confirmedNo,
    required this.code,
    this.isDuplicateHighlighted = false,
  });

  ConfirmedQrItem copyWith({
    int? confirmedNo,
    String? code,
    bool? isDuplicateHighlighted,
  }) {
    return ConfirmedQrItem(
      confirmedNo: confirmedNo ?? this.confirmedNo,
      code: code ?? this.code,
      isDuplicateHighlighted:
          isDuplicateHighlighted ?? this.isDuplicateHighlighted,
    );
  }
}
