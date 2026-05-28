class AppTransaction {
  final String id;
  final double amount;
  final String categoryId;
  final DateTime date;
  final String description;
  final String? details;
  final String? receiptImagePath;
  final String? ocrRawText;
  final bool isIncome;

  AppTransaction({
    required this.id,
    required this.amount,
    required this.categoryId,
    required this.date,
    required this.description,
    this.details,
    this.receiptImagePath,
    this.ocrRawText,
    required this.isIncome,
  });

  factory AppTransaction.fromMap(Map<String, dynamic> map) {
    return AppTransaction(
      id: map['id'],
      amount: map['amount'],
      categoryId: map['categoryId'],
      date: DateTime.parse(map['date']),
      description: map['description'],
      details: map['details'],
      receiptImagePath: map['receiptImagePath'],
      ocrRawText: map['ocrRawText'],
      isIncome: map['isIncome'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'categoryId': categoryId,
      'date': date.toIso8601String(),
      'description': description,
      'details': details,
      'receiptImagePath': receiptImagePath,
      'ocrRawText': ocrRawText,
      'isIncome': isIncome ? 1 : 0,
    };
  }
}
