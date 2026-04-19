import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../core/theme/app_colors.dart';
import '../../chat/presentation/chat_tab.dart';
import '../../orders/presentation/active_orders_tab.dart';
import '../../orders/presentation/create_order_screen.dart';
import '../../orders/models/order_model.dart';
import '../../orders/presentation/order_room_screen.dart';
import '../../orders/presentation/order_history_tab.dart';
import '../../settings/presentation/settings_tab.dart';

/// Main app shell: bottom navigation for Orders, Chat, History, and Settings.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _ordersRefreshSignal = 0;

  static const List<String> _titles = [
    'Active Orders',
    'Chats',
    'Order History',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader(
        title: Text(_titles[_index]),
        suffixes: _index == 0
            ? [
                FHeaderAction(
                  icon: const Icon(FIcons.plus),
                  onPress: () async {
                    final createdOrder = await Navigator.of(context)
                        .push<Order>(
                          MaterialPageRoute(
                            builder: (_) => const CreateOrderScreen(),
                          ),
                        );
                    if (createdOrder != null && context.mounted) {
                      setState(() {
                        _index = 0;
                        _ordersRefreshSignal++;
                      });
                      showFToast(
                        context: context,
                        title: const Text('Order created'),
                        description: const Text(
                          'Your order is now available for others to join.',
                        ),
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OrderRoomScreen(
                            initialOrder: createdOrder,
                            orderId: createdOrder.id,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ]
            : const [],
      ),
      footer: ColoredBox(
        color: AppColors.surface,
        child: FBottomNavigationBar(
          index: _index,
          onChange: (i) => setState(() => _index = i),
          safeAreaBottom: true,
          children: const [
            FBottomNavigationBarItem(
              icon: Icon(FIcons.shoppingCart),
              label: Text('Orders'),
            ),
            FBottomNavigationBarItem(
              icon: Icon(FIcons.messageCircle),
              label: Text('Chat'),
            ),
            FBottomNavigationBarItem(
              icon: Icon(FIcons.history),
              label: Text('History'),
            ),
            FBottomNavigationBarItem(
              icon: Icon(FIcons.settings),
              label: Text('Settings'),
            ),
          ],
        ),
      ),
      child: IndexedStack(
        index: _index,
        children: [
          ActiveOrdersTab(refreshSignal: _ordersRefreshSignal),
          const ChatTab(),
          const OrderHistoryTab(),
          const SettingsTab(),
        ],
      ),
    );
  }
}
