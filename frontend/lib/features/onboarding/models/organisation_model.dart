class Organisation {
  final int id;
  final String name;
  final String slug;
  final String shortCode;
  final String location;

  Organisation({
    required this.id,
    required this.name,
    this.slug = '',
    this.shortCode = '',
    this.location = '',
  });

  factory Organisation.fromJson(Map<String, dynamic> json) {
    return Organisation(
      id: json['id'],
      name: json['name'],
      slug: json['slug'] ?? '',
      shortCode: json['short_code'] ?? '',
      location: json['city'] ?? json['location'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'short_code': shortCode,
      'location': location,
    };
  }
}

class Campus {
  final int id;
  final int organisationId;
  final String name;
  final String slug;
  final String city;

  Campus({
    required this.id,
    required this.organisationId,
    required this.name,
    required this.slug,
    required this.city,
  });

  factory Campus.fromJson(Map<String, dynamic> json) {
    return Campus(
      id: json['id'],
      organisationId: json['organisation'],
      name: json['name'],
      slug: json['slug'] ?? '',
      city: json['city'] ?? '',
    );
  }
}

class PickupPoint {
  final int id;
  final int organisationId;
  final int? campusId;
  final String name;
  final String description;
  final bool isActive;
  final int sortOrder;

  PickupPoint({
    required this.id,
    required this.organisationId,
    required this.name,
    this.campusId,
    this.description = '',
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory PickupPoint.fromJson(Map<String, dynamic> json) {
    return PickupPoint(
      id: json['id'],
      organisationId: json['organisation'],
      campusId: json['campus'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      isActive: json['is_active'] ?? true,
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}
