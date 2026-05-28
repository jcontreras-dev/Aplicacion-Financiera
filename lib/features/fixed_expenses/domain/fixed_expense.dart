class FixedExpense {
  final String id;
  final String name;
  final double amount;
  final String categoryId;
  final int dayOfMonth; // día del mes en que vence
  final String? notes;

  FixedExpense({
    required this.id,
    required this.name,
    required this.amount,
    required this.categoryId,
    required this.dayOfMonth,
    this.notes,
  });

  factory FixedExpense.fromMap(Map<String, dynamic> map) {
    return FixedExpense(
      id: map['id'],
      name: map['name'],
      amount: map['amount'],
      categoryId: map['categoryId'],
      dayOfMonth: map['dayOfMonth'],
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'categoryId': categoryId,
      'dayOfMonth': dayOfMonth,
      'notes': notes,
    };
  }
}