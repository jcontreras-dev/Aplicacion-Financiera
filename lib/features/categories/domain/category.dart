class Category {
  final String id;
  final String name;
  final String icon;
  final String color;
  final bool isIncome;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.isIncome,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      icon: map['icon'],
      color: map['color'],
      isIncome: map['isIncome'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'isIncome': isIncome ? 1 : 0,
    };
  }
}
