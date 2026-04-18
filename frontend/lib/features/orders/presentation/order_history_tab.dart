import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../core/theme/app_colors.dart';

/// Past participation and orders where you reported an issue (placeholder).
class OrderHistoryTab extends StatelessWidget {
  const OrderHistoryTab({super.key});

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
                FIcons.history,
                size: 72,
                color: AppColors.accent.withOpacity(0.45),
              ),
              const SizedBox(height: 24),
              const Text(
                'Order history',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Completed orders you joined and cases where you raised an '
                'issue will show up here.',
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
