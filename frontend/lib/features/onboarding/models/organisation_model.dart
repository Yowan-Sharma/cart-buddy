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
