import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../core/theme/app_colors.dart';
import '../../chat/presentation/chat_tab.dart';
import '../../orders/presentation/active_orders_tab.dart';
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
                  onPress: () {
                    // TODO: Create order
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
        children: const [
          ActiveOrdersTab(),
          ChatTab(),
          OrderHistoryTab(),
          SettingsTab(),
        ],
      ),
    );
  }
}
