import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/models/user_model.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _bankAccountController;
  late TextEditingController _ifscController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).user!;
    _firstNameController = TextEditingController(text: user.firstName);
    _lastNameController = TextEditingController(text: user.lastName);
    _phoneController = TextEditingController(text: user.phone);
    _bankAccountController = TextEditingController(text: user.bankAccountNumber ?? '');
    _ifscController = TextEditingController(text: user.ifscCode ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _bankAccountController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final auth = ref.read(authStateProvider.notifier);
      final updatedData = {
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'phone': int.tryParse(_phoneController.text) ?? 0,
        'bank_account_number': _bankAccountController.text,
        'ifsc_code': _ifscController.text,
      };

      await auth.updateProfile(updatedData);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              FTextField(
                label: const Text('First Name'),
                control: FTextFieldControl.managed(
                  controller: _firstNameController,
                ),
              ),
              const SizedBox(height: 16),
              FTextField(
                label: const Text('Last Name'),
                control: FTextFieldControl.managed(
                  controller: _lastNameController,
                ),
              ),
              const SizedBox(height: 16),
              FTextField(
                label: const Text('Phone Number'),
                control: FTextFieldControl.managed(
                  controller: _phoneController,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Bank Details (For Receiving Funds)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              FTextField(
                label: const Text('Bank Account Number'),
                hint: 'Enter your bank account number',
                control: FTextFieldControl.managed(
                  controller: _bankAccountController,
                ),
              ),
              const SizedBox(height: 16),
              FTextField(
                label: const Text('IFSC Code'),
                hint: 'Enter bank IFSC code',
                control: FTextFieldControl.managed(
                  controller: _ifscController,
                ),
              ),
              const SizedBox(height: 40),
              FButton(
                onPress: _isLoading ? null : _save,
                child: _isLoading ? const Text('Saving...') : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
