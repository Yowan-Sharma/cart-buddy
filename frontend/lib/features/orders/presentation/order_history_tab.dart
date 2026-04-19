import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../core/theme/app_colors.dart';

/// Past participation and orders where you reported an issue (placeholder).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/service_providers.dart';
import '../../orders/data/order_service.dart';
import '../../orders/models/order_model.dart';
import '../../orders/presentation/order_room_screen.dart';

class OrderHistoryTab extends ConsumerStatefulWidget {
  const OrderHistoryTab({super.key});

  @override
  ConsumerState<OrderHistoryTab> createState() => _OrderHistoryTabState();
}

class _OrderHistoryTabState extends ConsumerState<OrderHistoryTab> {
  List<Order> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final service = ref.read(orderServiceProvider);
      final data = await service.getOrders(
        status: 'COMPLETED,WITHDRAWN',
        mine: true,
      );
      setState(() {
        _orders = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_orders.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = _orders[index];
          return _OrderHistoryCard(order: order);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(FIcons.history, size: 72, color: AppColors.accent.withValues(alpha: 0.45)),
              const SizedBox(height: 24),
              const Text(
                'No History Yet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Text(
                'Completed orders and withdrawn requests will show up here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSub, height: 1.45, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderHistoryCard extends StatelessWidget {
  final Order order;
  const _OrderHistoryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final isWithdrawn = order.status == 'WITHDRAWN';
    
    return FCard(
      title: Text(order.restaurantName),
      subtitle: Text('Order #${order.id} • ${order.title}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: ₹${order.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              FBadge(
                variant: isWithdrawn ? FBadgeVariant.destructive : FBadgeVariant.outline,
                child: Text(order.status),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FButton(
            variant: FButtonVariant.outline,
            onPress: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OrderRoomScreen(orderId: order.id)),
            ),
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }
}
