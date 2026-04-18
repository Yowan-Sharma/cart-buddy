import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          FTileGroup(
            children: [
              FTile(
                prefix: Icon(FIcons.user, color: AppColors.primary),
                title: const Text('Profile'),
                details: const Text('Account and preferences'),
                onPress: () {},
              ),
              FTile(
                prefix: Icon(FIcons.fileText, color: AppColors.primary),
                title: const Text('Terms of service'),
                onPress: () {},
              ),
              FTile(
                prefix: Icon(FIcons.shield, color: AppColors.primary),
                title: const Text('Privacy policy'),
                onPress: () {},
              ),
              FTile(
                prefix: Icon(FIcons.circleAlert, color: AppColors.primary),
                title: const Text('Help'),
                onPress: () {},
              ),
              FTile(
                prefix: Icon(FIcons.bookOpen, color: AppColors.primary),
                title: const Text('FAQs'),
                onPress: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          FTileGroup(
            children: [
              FTile(
                prefix: const Icon(FIcons.logOut, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
                onPress: () {
                  showDialog(
                    context: context,
                    builder: (context) => FDialog(
                      title: const Text('Logout'),
                      body: const Text('Are you sure you want to logout?'),
                      actions: [
                        FButton(
                          style: FButtonStyle.outline,
                          onPress: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        FButton(
                          onPress: () {
                            Navigator.pop(context);
                            ref.read(authStateProvider.notifier).logout();
                          },
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'More options can be added here as the app grows.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSub, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
