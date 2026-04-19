class SupportTicket {
  final int id;
  final String ticketId;
  final int? orderId;
  final String category;
  final String categoryDisplay;
  final String priority;
  final String priorityDisplay;
  final String status;
  final String statusDisplay;
  final String title;
  final String description;
  final double amountClaimed;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  SupportTicket({
    required this.id,
    required this.ticketId,
    this.orderId,
    required this.category,
    required this.categoryDisplay,
    required this.priority,
    required this.priorityDisplay,
    required this.status,
    required this.statusDisplay,
    required this.title,
    required this.description,
    required this.amountClaimed,
    required this.createdAt,
    this.resolvedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'],
      ticketId: json['ticket_id'],
      orderId: json['order'],
      category: json['category'],
      categoryDisplay: json['category_display'],
      priority: json['priority'],
      priorityDisplay: json['priority_display'],
      status: json['status'],
      statusDisplay: json['status_display'],
      title: json['title'],
      description: json['description'] ?? '',
      amountClaimed: double.tryParse(json['amount_claimed']?.toString() ?? '0') ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      resolvedAt: json['resolved_at'] != null ? DateTime.parse(json['resolved_at']) : null,
    );
  }
}

class TicketMessage {
  final int id;
  final String senderName;
  final String message;
  final String messageType;
  final DateTime createdAt;
  final bool isMine;

  TicketMessage({
    required this.id,
    required this.senderName,
    required this.message,
    required this.messageType,
    required this.createdAt,
    required this.isMine,
  });

  factory TicketMessage.fromJson(Map<String, dynamic> json, int currentUserId) {
    final sender = json['sender'] as Map<String, dynamic>;
    return TicketMessage(
      id: json['id'],
      senderName: sender['username'],
      message: json['message'],
      messageType: json['message_type'],
      createdAt: DateTime.parse(json['created_at']),
      isMine: sender['id'] == currentUserId,
    );
  }
}
