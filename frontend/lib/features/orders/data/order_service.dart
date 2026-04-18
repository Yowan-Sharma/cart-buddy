import 'package:dio/dio.dart';
import '../models/order_model.dart';

class OrderService {
  final Dio _dio;

  OrderService(this._dio);

  Future<List<Order>> getOrders() async {
    final response = await _dio.get('orders/');
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
      throw FormatException(
        'Unexpected orders response: ${data.runtimeType}',
      );
    }
    if (rows.isEmpty) {
      return [];
    }
    return rows
        .map((e) => Order.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> joinOrder(int orderId) async {
    try {
      await _dio.post('orders/$orderId/participants/');
    } catch (e) {
      rethrow;
    }
  }
}
