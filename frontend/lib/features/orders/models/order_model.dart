class Order {
  final int id;
  final int creatorId;
  final int? organisationId;
  final String title;
  final String restaurantName;
  final String meetingPoint;
  final String status;
  final int maxParticipants;
  final int currentParticipants;
  final String creatorName;
  final double totalAmount;
  final double baseAmount;
  final double minThresholdAmount;
  final DateTime cutoffAt;
  final bool canManage;

  Order({
    required this.id,
    required this.creatorId,
    required this.organisationId,
    required this.title,
    required this.restaurantName,
    required this.meetingPoint,
    required this.status,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.creatorName,
    required this.totalAmount,
    required this.baseAmount,
    required this.minThresholdAmount,
    required this.cutoffAt,
    required this.canManage,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final participants = json['participants'];
    final participantsCount = json['participants_count'];
    final int currentParticipants;
    if (participants is List) {
      currentParticipants = participants.length;
    } else if (participantsCount is int) {
      currentParticipants = participantsCount;
    } else if (participantsCount is num) {
      currentParticipants = participantsCount.toInt();
    } else {
      currentParticipants = 0;
    }

    final creator =
        json['creator_username'] ?? json['creator_name'] ?? 'Unknown';

    return Order(
      id: _readInt(json['id']),
      creatorId: _readInt(json['creator']),
      organisationId: json['organisation'] == null
          ? null
          : _readInt(json['organisation']),
      title: json['title']?.toString() ?? '',
      restaurantName: json['restaurant_name']?.toString() ?? '',
      meetingPoint: json['meeting_point']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      maxParticipants: _readInt(json['max_participants'], 10),
      currentParticipants: currentParticipants,
      creatorName: creator.toString(),
      totalAmount:
          double.tryParse(json['total_amount']?.toString() ?? '') ?? 0.0,
      baseAmount: double.tryParse(json['base_amount']?.toString() ?? '') ?? 0.0,
      minThresholdAmount:
          double.tryParse(json['min_threshold_amount']?.toString() ?? '') ??
              0.0,
      cutoffAt: DateTime.parse(json['cutoff_at'].toString()),
      canManage: json['can_manage'] == true,
    );
  }
}

int _readInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}
