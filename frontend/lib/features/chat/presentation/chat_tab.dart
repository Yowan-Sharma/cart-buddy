import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../core/theme/app_colors.dart';

/// Order-scoped chats: one thread per order (UI placeholder).
class ChatTab extends StatelessWidget {
  const ChatTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FIcons.messageCircle,
                size: 72,
                color: AppColors.accent.withOpacity(0.45),
              ),
              const SizedBox(height: 24),
              const Text(
                'Order chats',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Each active order will have its own chat. Open an order from '
                'Active Orders to message your group.',
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
      ),
    );
  }
}
