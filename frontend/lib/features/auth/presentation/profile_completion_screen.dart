import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';

class ProfileCompletionScreen extends ConsumerStatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  ConsumerState<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState
    extends ConsumerState<ProfileCompletionScreen> {
  String _username = '';
  String _phone = '';
  String? _gender;
  bool _isLoading = false;

  Future<void> _submit() async {
    if (_username.trim().isEmpty) {
      _showError('Please choose a username.');
      return;
    }
    if (_phone.trim().isEmpty || int.tryParse(_phone.trim()) == null) {
      _showError('Please enter a valid phone number.');
      return;
    }
    if (_gender == null) {
      _showError('Please select your gender.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authStateProvider.notifier).updateProfile({
        'username': _username.trim(),
        'phone': int.parse(_phone.trim()),
        'gender': _gender,
      });
      // Router will redirect away once user profile is fully set
    } catch (e) {
      if (mounted) _showError(_getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => FDialog(
        title: const Text('Complete Your Profile'),
        body: Text(message),
        actions: [
          FButton(
            onPress: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getErrorMessage(dynamic e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        if (data.containsKey('errors')) {
          final errors = data['errors'] as Map;
          return errors.entries.map((entry) {
            final value = entry.value;
            return "${entry.key}: ${value is List ? value.join(', ') : value}";
          }).join('\n');
        }
        if (data.containsKey('error')) return data['error'].toString();
      }
      return e.message ?? 'An unexpected error occurred';
    }
    return e.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FScaffold(
        child: Material(
          color: AppColors.background,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  const Icon(Icons.person_outline_rounded,
                      size: 72, color: AppColors.accent),
                  const SizedBox(height: 24),
                  const Text(
                    'Almost there!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Just a few more details to complete\nyour CartBuddy profile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSub,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 40),
                  FTextField(
                    label: const Text('Username'),
                    hint: 'Choose a unique username',
                    control: FTextFieldControl.managed(
                      onChange: (v) => _username = v.text,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FTextField(
                    label: const Text('Phone Number'),
                    hint: 'Enter your phone number',
                    keyboardType: TextInputType.phone,
                    control: FTextFieldControl.managed(
                      onChange: (v) => _phone = v.text,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Gender',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _GenderOption(
                        label: 'Male',
                        isSelected: _gender == 'Male',
                        onTap: () => setState(() => _gender = 'Male'),
                      ),
                      const SizedBox(width: 12),
                      _GenderOption(
                        label: 'Female',
                        isSelected: _gender == 'Female',
                        onTap: () => setState(() => _gender = 'Female'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  FButton(
                    onPress: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Complete Profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GenderOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.textSub.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppColors.accent : AppColors.primary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
