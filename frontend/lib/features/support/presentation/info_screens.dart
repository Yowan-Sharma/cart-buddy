import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class StaticContentScreen extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const StaticContentScreen({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StaticContentScreen(
      title: 'FAQs',
      children: [
        _buildSection('Ordering', [
          _buildItem('How do I join an order?', 'Browse the "Active Orders" tab and tap "Join" on any open order.'),
          _buildItem('Can I cancel my items?', 'You can remove items while the order is in "DRAFT" or "OPEN" status.'),
        ]),
        _buildSection('Payments', [
          _buildItem('Is my money safe?', 'Yes, funds are held in escrow until you confirm delivery with an OTP.'),
          _buildItem('How do refunds work?', 'If an order is withdrawn, your money is automatically returned to your wallet.'),
        ]),
        _buildSection('Account', [
          _buildItem('How do I withdraw funds?', 'Go to Settings > Withdraw Funds and enter your bank details.'),
        ]),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(height: 16),
        ...items,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildItem(String q, String a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 4),
          Text(a, style: const TextStyle(color: AppColors.textSub, fontSize: 14)),
        ],
      ),
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StaticContentScreen(
      title: 'Terms of Service',
      children: [
        Text('1. Acceptance of Terms', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('By using CartBuddy, you agree to these terms...'),
        SizedBox(height: 24),
        Text('2. User Conduct', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('You are responsible for your orders and interactions...'),
      ],
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StaticContentScreen(
      title: 'Privacy Policy',
      children: [
        Text('Data Collection', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('We collect your name, email, and phone for order coordination...'),
        SizedBox(height: 24),
        Text('Financial Data', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('Payment information is handled securely via Razorpay...'),
      ],
    );
  }
}
