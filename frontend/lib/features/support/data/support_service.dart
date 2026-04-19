import 'package:dio/dio.dart';
import '../models/support_ticket.dart';

class SupportService {
  final Dio _dio;

  SupportService(this._dio);

  Future<List<SupportTicket>> getMyTickets() async {
    final response = await _dio.get('disputes/my/');
    final List<dynamic> rows = response.data is List ? response.data : (response.data['results'] ?? []);
    return rows.map((e) => SupportTicket.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<SupportTicket> getTicketDetail(String ticketId) async {
    final response = await _dio.get('disputes/$ticketId/');
    return SupportTicket.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<TicketMessage>> getTicketMessages(String ticketId, int currentUserId) async {
    final response = await _dio.get('disputes/$ticketId/messages/');
    final List<dynamic> rows = response.data is List ? response.data : (response.data['results'] ?? []);
    return rows.map((e) => TicketMessage.fromJson(Map<String, dynamic>.from(e as Map), currentUserId)).toList();
  }

  Future<TicketMessage> sendMessage(String ticketId, String message, int currentUserId) async {
    final response = await _dio.post(
      'disputes/$ticketId/messages/create/',
      data: {'message': message},
    );
    return TicketMessage.fromJson(Map<String, dynamic>.from(response.data as Map), currentUserId);
  }

  Future<SupportTicket> createTicket({
    required String title,
    required String description,
    required String category,
    int? orderId,
    double amountClaimed = 0.0,
  }) async {
    final response = await _dio.post(
      'disputes/',
      data: {
        'title': title,
        'description': description,
        'category': category,
        if (orderId != null) 'order_id': orderId,
        'amount_claimed': amountClaimed,
      },
    );
    return SupportTicket.fromJson(Map<String, dynamic>.from(response.data as Map));
  }
}
