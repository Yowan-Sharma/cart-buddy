import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../settings/presentation/profile_edit_screen.dart';
import '../providers/wallet_provider.dart';

class WithdrawalScreen extends ConsumerStatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  ConsumerState<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends ConsumerState<WithdrawalScreen> {
  final _amountController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amountStr = _amountController.text.trim();
    if (amountStr.isEmpty) return;

    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      _showToast('Invalid Amount', 'Please enter a valid amount greater than zero.');
      return;
    }

    final wallet = ref.read(walletBalanceProvider).value;
    if (wallet == null || amount > wallet.balance) {
      _showToast('Insufficient Balance', 'You cannot withdraw more than your current balance.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final service = ref.read(walletServiceProvider);
      await service.withdrawFunds(amount);
      
      if (!mounted) return;
      ref.invalidate(walletBalanceProvider);
      
      showDialog(
        context: context,
        builder: (context) => FDialog(
          title: const Text('Request Submitted'),
          body: const Text('Your withdrawal request has been submitted successfully. Funds will be transferred to your bank account soon.'),
          actions: [
            FButton(
              onPress: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to settings
              },
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showToast('Request Failed', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showToast(String title, String description) {
    showFToast(
      context: context,
      title: Text(title),
      description: Text(description),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user!;
    final walletAsync = ref.watch(walletBalanceProvider);
    
    final hasBankDetails = (user.bankAccountNumber?.isNotEmpty ?? false) && 
                          (user.ifscCode?.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdraw Funds'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Balance Card
            FCard(
              title: const Text('Available Balance'),
              child: walletAsync.when(
                data: (w) => Text(
                  '₹${w.balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Error loading balance'),
              ),
            ),
            const SizedBox(height: 24),

            // Bank Details Section
            const Text(
              'Destination Bank Account',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            if (!hasBankDetails) ...[
              FAlert(
                title: const Text('Missing Bank Details: You need to add your bank account details before you can withdraw funds.'),
                icon: const Icon(FIcons.circleAlert),
              ),
              const SizedBox(height: 16),
              FButton(
                variant: FButtonVariant.outline,
                onPress: () => Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const ProfileEditScreen())
                ),
                child: const Text('Add Bank Details'),
              ),
            ] else ...[
              FCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account: ${user.bankAccountNumber}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'IFSC: ${user.ifscCode}',
                      style: const TextStyle(color: AppColors.textSub, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),

            // Amount Input
            if (hasBankDetails) ...[
              FTextField(
                label: const Text('Withdrawal Amount'),
                hint: '0.00',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                control: FTextFieldControl.managed(
                  controller: _amountController,
                ),
              ),
              const SizedBox(height: 40),
              FButton(
                onPress: _isLoading ? null : _submit,
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Withdraw to Bank'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
