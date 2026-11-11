/// One entry of the list the reference app keeps.
class Item {
  const Item({
    required this.id,
    required this.title,
    this.description,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'description': ?description,
    'createdAt': createdAt.toIso8601String(),
  };
}
