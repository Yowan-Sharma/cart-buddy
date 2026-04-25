import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/order_model.dart';
import '../models/order_room_models.dart';

class OrderService {
  final Dio _dio;

  OrderService(this._dio);

  Future<List<Order>> getOrders({
    String? status,
    bool? mine,
    String? search,
    int? campus,
  }) async {
    final response = await _dio.get('orders/', queryParameters: {
      if (status != null) 'status': status,
      if (mine != null) 'mine': mine.toString(),
      if (search != null) 'search': search,
      if (campus != null) 'campus': campus.toString(),
    });
    final data = response.data;
    // Empty list, null body, or paginated empty results should all yield [] without throwing.
    if (data == null) {
      return [];
    }
    final List<dynamic> rows;
    if (data is List) {
      rows = data;
    } else if (data is Map) {
      final raw = data['results'];
      if (raw is List) {
        rows = raw;
      } else {
        return [];
      }
    } else {
      throw FormatException('Unexpected orders response: ${data.runtimeType}');
    }
    if (rows.isEmpty) {
      return [];
    }
    return rows
        .map((e) => Order.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Order> getOrder(int orderId) async {
    final response = await _dio.get('orders/$orderId/');
    return Order.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<OrderParticipantModel>> getParticipants(int orderId) async {
    final response = await _dio.get('orders/$orderId/participants/');
    final rows = _asList(response.data);
    return rows
        .map(
          (e) => OrderParticipantModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<List<OrderItemModel>> getItems(int orderId) async {
    final response = await _dio.get('orders/$orderId/items/');
    final rows = _asList(response.data);
    return rows
        .map(
          (e) => OrderItemModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<List<OrderChatMessageModel>> getMessages(int orderId) async {
    final response = await _dio.get('chats/orders/$orderId/messages/');
    final rows = _asList(response.data);
    return rows
        .map(
          (e) => OrderChatMessageModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<OrderChatMessageModel> sendMessage(int orderId, String message) async {
    final response = await _dio.post(
      'chats/orders/$orderId/messages/',
      data: {'message': message},
    );
    return OrderChatMessageModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> joinOrder(int orderId) async {
    try {
      await _dio.post('orders/$orderId/participants/');
    } catch (e) {
      rethrow;
    }
  }

  Future<OrderItemModel> addItem({
    required int orderId,
    required String name,
    required int quantity,
    required double unitPrice,
    String specialInstructions = '',
  }) async {
    final response = await _dio.post(
      'orders/$orderId/items/',
      data: {
        'name': name,
        'quantity': quantity,
        'unit_price': unitPrice.toStringAsFixed(2),
        'line_total': (unitPrice * quantity).toStringAsFixed(2),
        'special_instructions': specialInstructions,
      },
    );
    return OrderItemModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<OrderItemModel>> submitCart(int orderId) async {
    final response = await _dio.post('orders/$orderId/cart/submit/');
    final rows = _asList(response.data);
    return rows
        .map(
          (e) => OrderItemModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<OrderItemModel> approveItem(int itemId, {String reason = ''}) async {
    final response = await _dio.post(
      'orders/items/$itemId/approve/',
      data: {'reason': reason},
    );
    return OrderItemModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<OrderItemModel> rejectItem(
    int itemId, {
    required String reason,
  }) async {
    final response = await _dio.post(
      'orders/items/$itemId/reject/',
      data: {'reason': reason},
    );
    return OrderItemModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<Order> createOrder({
    required int organisationId,
    required int pickupPointId,
    required String title,
    required String restaurantName,
    String meetingNotes = '',
    double baseAmount = 0.0,
    double minThresholdAmount = 0.0,
  }) async {
    final response = await _dio.post(
      'orders/',
      data: {
        'organisation': organisationId,
        'pickup_point': pickupPointId,
        'title': title,
        'restaurant_name': restaurantName,
        'meeting_notes': meetingNotes,
        'base_amount': baseAmount.toStringAsFixed(2),
        'min_threshold_amount': minThresholdAmount.toStringAsFixed(2),
        'max_participants': 10,
      },
    );

    return Order.fromJson(Map<String, dynamic>.from(response.data as Map));
  }


  Future<Order> updateOrderStatus(int orderId, String status, {String reason = ''}) async {
    final response = await _dio.post(
      'orders/$orderId/status/',
      data: {'status': status, 'reason': reason},
    );
    return Order.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<Map<String, dynamic>> getMyOtp(int orderId) async {
    final response = await _dio.get('orders/$orderId/handover-otp/me/');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> verifyOtp(int orderId, int participantId, String otp) async {
    await _dio.post(
      'orders/$orderId/handover-otp/verify/',
      data: {'participant_id': participantId, 'otp': otp},
    );
  }

  Future<PaymentOrderModel> createPayment(int orderId) async {
    debugPrint('[CartBuddyPayment][api] createPayment request | order_id=$orderId');
    final response = await _dio.post(
      'payments/orders/create/',
      data: {'order_id': orderId},
    );
    final model = PaymentOrderModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
    debugPrint('[CartBuddyPayment][api] createPayment response | tx=${model.transactionId} amount=${model.amount} gateway_order=${model.gatewayOrderId}');
    return model;
  }

  Future<List<dynamic>> getCampuses(int organisationId) async {
    final response = await _dio.get("organisations/$organisationId/campuses/");
    return _asList(response.data);
  }

  Future<void> verifyPayment({
    required int paymentTransactionId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    debugPrint('[CartBuddyPayment][api] verifyPayment request | tx=$paymentTransactionId payment_id=$razorpayPaymentId signature_present=${razorpaySignature.isNotEmpty}');
    await _dio.post(
      'payments/orders/verify/',
      data: {
        'payment_transaction_id': paymentTransactionId,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_signature': razorpaySignature,
      },
    );
    debugPrint('[CartBuddyPayment][api] verifyPayment success | tx=$paymentTransactionId');
  }

  String get baseUrl => _dio.options.baseUrl;
}

List<dynamic> _asList(dynamic data) {
  if (data is List) return data;
  if (data is Map && data['results'] is List) {
    return data['results'] as List<dynamic>;
  }
  return const [];
}
