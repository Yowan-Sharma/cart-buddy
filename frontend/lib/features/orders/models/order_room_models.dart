class OrderParticipantModel {
  final int id;
  final int orderId;
  final int userId;
  final String userName;
  final String role;
  final String status;
  final double amountDue;
  final double amountPaid;

  OrderParticipantModel({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.userName,
    required this.role,
    required this.status,
    required this.amountDue,
    required this.amountPaid,
  });

  factory OrderParticipantModel.fromJson(Map<String, dynamic> json) {
    return OrderParticipantModel(
      id: _readInt(json['id']),
      orderId: _readInt(json['order']),
      userId: _readInt(json['user']),
      userName: json['user_username']?.toString() ?? 'Unknown',
      role: json['role']?.toString() ?? 'JOINER',
      status: json['status']?.toString() ?? 'JOINED',
      amountDue: _readDouble(json['amount_due']),
      amountPaid: _readDouble(json['amount_paid']),
    );
  }
}

class OrderItemModel {
  final int id;
  final int orderId;
  final int participantId;
  final int participantUserId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String specialInstructions;
  final String status;
  final String reviewReason;
  final String addedByUsername;
  final String? reviewedByUsername;
  final bool isActive;

  OrderItemModel({
    required this.id,
    required this.orderId,
    required this.participantId,
    required this.participantUserId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.specialInstructions,
    required this.status,
    required this.reviewReason,
    required this.addedByUsername,
    required this.reviewedByUsername,
    required this.isActive,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: _readInt(json['id']),
      orderId: _readInt(json['order']),
      participantId: _readInt(json['participant']),
      participantUserId: _readInt(json['participant_user_id']),
      name: json['name']?.toString() ?? '',
      quantity: _readInt(json['quantity'], 1),
      unitPrice: _readDouble(json['unit_price']),
      lineTotal: _readDouble(json['line_total']),
      specialInstructions: json['special_instructions']?.toString() ?? '',
      status: json['status']?.toString() ?? 'DRAFT',
      reviewReason: json['review_reason']?.toString() ?? '',
      addedByUsername: json['added_by_username']?.toString() ?? 'Unknown',
      reviewedByUsername: json['reviewed_by_username']?.toString(),
      isActive: json['is_active'] ?? true,
    );
  }
}

class OrderChatMessageModel {
  final int id;
  final int orderId;
  final int senderId;
  final String senderUsername;
  final String messageType;
  final String message;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  OrderChatMessageModel({
    required this.id,
    required this.orderId,
    required this.senderId,
    required this.senderUsername,
    required this.messageType,
    required this.message,
    required this.metadata,
    required this.createdAt,
  });

  factory OrderChatMessageModel.fromJson(Map<String, dynamic> json) {
    return OrderChatMessageModel(
      id: _readInt(json['id']),
      orderId: _readInt(json['order']),
      senderId: _readInt(json['sender']),
      senderUsername: json['sender_username']?.toString() ?? 'Unknown',
      messageType: json['message_type']?.toString() ?? 'TEXT',
      message: json['message']?.toString() ?? '',
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class PaymentOrderModel {
  final int transactionId;
  final String keyId;
  final String gatewayOrderId;
  final int amount;
  final String currency;

  PaymentOrderModel({
    required this.transactionId,
    required this.keyId,
    required this.gatewayOrderId,
    required this.amount,
    required this.currency,
  });

  factory PaymentOrderModel.fromJson(Map<String, dynamic> json) {
    final tx = Map<String, dynamic>.from(
      json['payment_transaction'] as Map? ?? const {},
    );
    final razorpay = Map<String, dynamic>.from(
      json['razorpay'] as Map? ?? const {},
    );
    return PaymentOrderModel(
      transactionId: _readInt(tx['id']),
      keyId: razorpay['key_id']?.toString() ?? '',
      gatewayOrderId: razorpay['order_id']?.toString() ?? '',
      amount: _readInt(razorpay['amount']),
      currency: razorpay['currency']?.toString() ?? 'INR',
    );
  }
}

int _readInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

double _readDouble(dynamic value, [double fallback = 0]) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}
