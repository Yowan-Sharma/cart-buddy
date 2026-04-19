import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/providers/service_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../models/order_model.dart';
import 'order_room_screen.dart';

/// Active orders for the user's organisation (content only; shell provides header + nav).
class ActiveOrdersTab extends ConsumerStatefulWidget {
  final int refreshSignal;

  const ActiveOrdersTab({super.key, this.refreshSignal = 0});

  @override
  ConsumerState<ActiveOrdersTab> createState() => _ActiveOrdersTabState();
}

class _ActiveOrdersTabState extends ConsumerState<ActiveOrdersTab> {
  List<Order> orders = [];
  bool isLoading = true;
  String _searchQuery = '';
  int? _selectedCampusId;
  List<dynamic> _campuses = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    await Future.wait([
      _fetchCampuses(),
      _fetchOrders(),
    ]);
  }

  Future<void> _fetchCampuses() async {
    try {
      final user = ref.read(authStateProvider).user;
      if (user?.organisation == null) return;
      
      final service = ref.read(orderServiceProvider);
      final data = await service.getCampuses(user!.organisation!);
      if (mounted) {
        setState(() => _campuses = data);
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant ActiveOrdersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      setState(() => isLoading = true);
      _fetchOrders();
    }
  }

  Future<void> _fetchOrders() async {
    try {
      final service = ref.read(orderServiceProvider);
      final data = await service.getOrders(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        campus: _selectedCampusId,
      );
      if (!mounted) return;
      setState(() {
        orders = data
            .where((o) =>
                o.status == 'OPEN' ||
                o.status == 'LOCKED' ||
                o.status == 'PLACED' ||
                o.status == 'ARRIVED' ||
                o.status == 'IN_PROGRESS')
            .toList();
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        if (context.mounted) {
          showFToast(
            context: context,
            title: const Text('Failed to fetch orders'),
            description: Text(e.toString()),
          );
        }
      }
    }
  }

  Future<void> _confirmWithdraw(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => FDialog(
        title: const Text('Withdraw Order?'),
        body: const Text(
          'Are you sure you want to withdraw this order? All participants will be notified.',
        ),
        actions: [
          FButton(
            onPress: () => Navigator.pop(context, false),
            variant: FButtonVariant.outline,
            child: const Text('Cancel'),
          ),
          FButton(
            onPress: () => Navigator.pop(context, true),
            variant: FButtonVariant.destructive,
            child: const Text('Yes, Withdraw'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(orderServiceProvider)
            .updateOrderStatus(order.id, 'WITHDRAWN');
        _fetchOrders();
        if (mounted && context.mounted) {
          showFToast(
              context: context,
              title: const Text('Order withdrawn successfully'));
        }
      } catch (e) {
        if (mounted && context.mounted) {
          showFToast(
              context: context,
              title: const Text('Could not withdraw'),
              description: Text(e.toString()));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // Search and Filters
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                FTextField(
                  label: const Text('Search Orders'),
                  hint: 'Search by store or title...',
                  control: FTextFieldControl.managed(
                    controller: _searchController,
                    onChange: (value) {
                      setState(() => _searchQuery = value.text);
                      _fetchOrders();
                    },
                  ),
                ),
                const SizedBox(height: 12),
                if (_campuses.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _campuses.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          final isSelected = _selectedCampusId == null;
                          return _FilterChip(
                            label: 'All Locations',
                            isSelected: isSelected,
                            onTap: () {
                              setState(() => _selectedCampusId = null);
                              _fetchOrders();
                            },
                          );
                        }
                        final campus = _campuses[index - 1];
                        final isSelected = _selectedCampusId == campus['id'];
                        return _FilterChip(
                          label: campus['name'],
                          isSelected: isSelected,
                          onTap: () {
                            setState(() => _selectedCampusId = campus['id']);
                            _fetchOrders();
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchOrders,
                    child: orders.isEmpty
                        ? LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: _EmptyState(onRefresh: _fetchOrders),
                                ),
                              );
                            },
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: orders.length,
                            itemBuilder: (context, index) {
                              return _OrderCard(
                                order: orders[index],
                                onWithdraw: () => _confirmWithdraw(orders[index]),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.textSub.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.primary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onWithdraw;

  const _OrderCard({required this.order, this.onWithdraw});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    OrderRoomScreen(initialOrder: order, orderId: order.id),
              ),
            );
          },
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'App/Service',
                              style: TextStyle(
                                color: AppColors.textSub,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order.restaurantName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  FIcons.mapPin,
                                  size: 14,
                                  color: AppColors.textSub,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  order.meetingPoint,
                                  style: const TextStyle(
                                    color: AppColors.textSub,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: order.status == 'PLACED'
                              ? Colors.blue.withValues(alpha: 0.1)
                              : order.status == 'ARRIVED'
                                  ? Colors.orange.withValues(alpha: 0.1)
                                  : order.totalAmount >=
                                          order.minThresholdAmount
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : AppColors.secondary
                                          .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          order.status == 'PLACED'
                              ? 'Order Placed!'
                              : order.status == 'ARRIVED'
                                  ? 'Host Received!'
                                  : order.totalAmount >=
                                          order.minThresholdAmount
                                      ? 'Threshold Met!'
                                      : '₹${order.totalAmount.toStringAsFixed(0)} / ₹${order.minThresholdAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: order.status == 'PLACED'
                                ? Colors.blue
                                : order.status == 'ARRIVED'
                                    ? Colors.orange
                                    : order.totalAmount >=
                                            order.minThresholdAmount
                                        ? Colors.green
                                        : AppColors.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (order.totalAmount /
                              (order.minThresholdAmount > 0
                                  ? order.minThresholdAmount
                                  : 1))
                          .clamp(0.0, 1.0),
                      backgroundColor: AppColors.background,
                      color: order.totalAmount >= order.minThresholdAmount
                          ? Colors.green
                          : AppColors.secondary,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _InfoTile(
                        icon: FIcons.clock,
                        label: 'Closes',
                        value: _formatTime(order.cutoffAt),
                      ),
                      const Spacer(),
                      _InfoTile(
                        icon: FIcons.user,
                        label: 'Creator',
                        value: order.creatorName,
                      ),
                      const Spacer(),
                      _InfoTile(
                        icon: FIcons.wallet,
                        label: 'Total',
                        value: '₹${order.totalAmount.toStringAsFixed(0)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FButton(
                          onPress: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => OrderRoomScreen(
                                  initialOrder: order,
                                  orderId: order.id,
                                ),
                              ),
                            );
                          },
                          child: const Text('Open Room'),
                        ),
                      ),
                      if (order.canManage && (order.status == 'OPEN' || order.status == 'LOCKED')) ...[
                        const SizedBox(width: 12),
                        FButton(
                          onPress: onWithdraw,
                          variant: FButtonVariant.destructive,
                          child: const Icon(FIcons.trash),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  String _formatTime(DateTime dateTime) {
    return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppColors.textSub),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: AppColors.textSub, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FIcons.shoppingCart,
            size: 80,
            color: AppColors.accent.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          const Text(
            'No active orders nearby',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first one to start an order!',
            style: TextStyle(color: AppColors.textSub),
          ),
          const SizedBox(height: 32),
          FButton(onPress: onRefresh, child: const Text('Refresh Feed')),
        ],
      ),
    );
  }
}
