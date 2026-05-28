class Budget {
  final String categoryId;
  final double amountLimit;

  Budget({required this.categoryId, required this.amountLimit});

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'amountLimit': amountLimit,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      categoryId: map['categoryId'] as String,
      amountLimit: map['amountLimit'] as double,
    );
  }
}
