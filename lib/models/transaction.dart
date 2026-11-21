enum TxType { income, expense }

/// Nguồn tạo giao dịch.
enum TxSource { manual, notification, screenshot, paste }

class Transaction {
  final int? id;

  /// Số tiền (VND), luôn dương.
  final int amount;
  final TxType type;
  final String categoryId;
  final String note;
  final DateTime date;
  final TxSource source;
  final String? bank;
  final String? rawText;

  /// Giao dịch tự thêm, người dùng chưa xác nhận.
  final bool needsReview;

  const Transaction({
    this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    this.note = '',
    required this.date,
    this.source = TxSource.manual,
    this.bank,
    this.rawText,
    this.needsReview = false,
  });

  int get signedAmount => type == TxType.income ? amount : -amount;

  Transaction copyWith({
    int? id,
    int? amount,
    TxType? type,
    String? categoryId,
    String? note,
    DateTime? date,
    bool? needsReview,
  }) =>
      Transaction(
        id: id ?? this.id,
        amount: amount ?? this.amount,
        type: type ?? this.type,
        categoryId: categoryId ?? this.categoryId,
        note: note ?? this.note,
        date: date ?? this.date,
        source: source,
        bank: bank,
        rawText: rawText,
        needsReview: needsReview ?? this.needsReview,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'amount': amount,
        'type': type.name,
        'category_id': categoryId,
        'note': note,
        'date': date.millisecondsSinceEpoch,
        'source': source.name,
        'bank': bank,
        'raw_text': rawText,
        'needs_review': needsReview ? 1 : 0,
      };

  factory Transaction.fromMap(Map<String, Object?> m) => Transaction(
        id: m['id'] as int?,
        amount: m['amount'] as int,
        type: TxType.values.byName(m['type'] as String),
        categoryId: m['category_id'] as String,
        note: (m['note'] as String?) ?? '',
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        source: TxSource.values.byName(m['source'] as String),
        bank: m['bank'] as String?,
        rawText: m['raw_text'] as String?,
        needsReview: (m['needs_review'] as int? ?? 0) == 1,
      );
}
