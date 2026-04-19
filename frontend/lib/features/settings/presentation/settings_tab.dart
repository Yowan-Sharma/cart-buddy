import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';

import '../../payments/providers/wallet_provider.dart';
import '../../payments/presentation/withdrawal_screen.dart';
import '../../support/presentation/help_screen.dart';
import '../../support/presentation/info_screens.dart';
import 'profile_edit_screen.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletBalanceProvider);

    return Container(
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          FTileGroup(
            children: [
              FTile(
                prefix: Icon(FIcons.wallet, color: AppColors.primary),
                title: const Text('My Wallet'),
                details: walletAsync.when(
                  data: (w) => Text(
                    '₹${w.balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  loading: () => const Text('Loading...'),
                  error: (_, __) => const Text('Error loading balance'),
                ),
                onPress: () => ref.refresh(walletBalanceProvider),
              ),
              FTile(
                prefix: Icon(FIcons.landmark, color: AppColors.primary),
                title: const Text('Withdraw Funds'),
                details: const Text('Transfer to bank account'),
                onPress: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WithdrawalScreen()),
                ),
              ),
              FTile(
                prefix: Icon(FIcons.user, color: AppColors.primary),
                title: const Text('Profile'),
                details: const Text('Account and preferences'),
                onPress: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
                ),
              ),
              FTile(
                prefix: Icon(FIcons.fileText, color: AppColors.primary),
                title: const Text('Terms of service'),
                onPress: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())),
              ),
              FTile(
                prefix: Icon(FIcons.shield, color: AppColors.primary),
                title: const Text('Privacy policy'),
                onPress: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen())),
              ),
              FTile(
                prefix: Icon(FIcons.messageCircle, color: AppColors.primary),
                title: const Text('Help'),
                onPress: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
              ),
              FTile(
                prefix: Icon(FIcons.bookOpen, color: AppColors.primary),
                title: const Text('FAQs'),
                onPress: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FAQScreen())),
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
                          variant: FButtonVariant.outline,
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
