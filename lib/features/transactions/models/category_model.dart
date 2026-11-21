
class CategoryModel {
  final String id;
  final String userId;
  final String name;
  final String type;
  final String? icon;
  final String? color;

  const CategoryModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.icon,
    this.color,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'].toString(),
      userId: map['user_id'].toString(),
      name: map['name'] as String,
      type: map['type'] as String,
      icon: map['icon'] as String?,
      color: map['color'] as String?,
    );
  }
}
