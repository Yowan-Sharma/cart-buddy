import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/providers/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../orders/models/order_model.dart';
import '../../orders/presentation/order_room_screen.dart';

/// Order-scoped chats: one thread per order (UI placeholder).
class ChatTab extends ConsumerStatefulWidget {
  const ChatTab({super.key});

  @override
  ConsumerState<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<ChatTab> {
  List<Order> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final orders = await ref.read(orderServiceProvider).getOrders(
        mine: true,
      );
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = _orders[index];
                      return _ChatOrderCard(order: order);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FIcons.messageSquare,
              size: 72,
              color: AppColors.accent.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 24),
            const Text(
              'No active chats',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Create or join an order to start chatting with the group.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSub,
                height: 1.45,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatOrderCard extends StatelessWidget {
  final Order order;
  const _ChatOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderRoomScreen(
              initialOrder: order,
              orderId: order.id,
            ),
          ),
        );
      },
      child: FCard(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Icon(FIcons.messageSquare, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.title.isEmpty ? order.restaurantName : order.title),
                  Text(
                    '${order.restaurantName} • ${order.meetingPoint}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSub,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(FIcons.chevronRight, size: 16),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              FBadge(
                variant: FBadgeVariant.outline,
                child: Text(order.status),
              ),
              const SizedBox(width: 8),
              Text(
                '${order.currentParticipants} participants',
                style: TextStyle(color: AppColors.textSub, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
