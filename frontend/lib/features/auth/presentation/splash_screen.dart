import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Shown only on cold start while [AuthNotifier] runs refresh token / session bootstrap.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/images/logo1.png",
              width: 150,
              height: 150,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.shopping_cart,
                size: 80,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              color: AppColors.accent,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
