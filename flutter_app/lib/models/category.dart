class MedicalCategory {
  final String id;
  final String name;
  final String icon;
  final String? description;

  MedicalCategory({
    required this.id,
    required this.name,
    required this.icon,
    this.description,
  });

  factory MedicalCategory.fromJson(Map<String, dynamic> json) {
    return MedicalCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String? ?? '📋',
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    if (description != null) 'description': description,
  };
}
