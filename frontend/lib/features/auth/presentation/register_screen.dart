import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_services.dart';
import '../../../core/providers/auth_provider.dart';
import '../data/google_oauth_service.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  String? _gender;

  String _firstName = '';
  String _lastName = '';
  String _username = '';
  String _email = '';
  String _phone = '';
  String _password = '';
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  final _googleOAuth = GoogleOAuthService();

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      final idToken = await _googleOAuth.getIdToken();
      final result = await ref.read(authServiceProvider).googleLogin(idToken);
      if (result.containsKey('access') && mounted) {
        await ref.read(authStateProvider.notifier).login(
          result['access'] as String,
          refreshToken: result['refresh'] as String?,
        );
      }
    } catch (e) {
      if (mounted) _showErrorModal(context, _getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _showSuccessModal(BuildContext context, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => FDialog(
        title: const Text('Account Created'),
        body: Text(message),
        actions: [
          FButton(
            onPress: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('Start Onboarding'),
          ),
        ],
      ),
    );
  }

  void _showErrorModal(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => FDialog(
        title: const Text('Registration Failed'),
        body: Text(message),
        actions: [
          FButton(
            onPress: () => Navigator.pop(context),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (context) => FScaffold(
          child: Material(
            color: AppColors.background,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(0, 60, 0, 0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.05),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          "assets/images/logo1.png",
                          width: 200,
                          height: 200,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.shopping_cart,
                            size: 80,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ),
                    const Text(
                      'Join carts. Split costs.\nOrder anything.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSub,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    // Name Row
                    Row(
                      children: [
                        Expanded(
                          child: FTextField(
                            label: const Text('First Name'),
                            hint: 'Enter first name',
                            control: FTextFieldControl.managed(
                              onChange: (value) => _firstName = value.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FTextField(
                            label: const Text('Last Name'),
                            hint: 'Enter last name',
                            control: FTextFieldControl.managed(
                              onChange: (value) => _lastName = value.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    FTextField(
                      label: const Text('Username'),
                      hint: 'Choose a username',
                      control: FTextFieldControl.managed(
                        onChange: (value) => _username = value.text,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    FTextField(
                      label: const Text('Email'),
                      hint: 'Enter your email',
                      keyboardType: TextInputType.emailAddress,
                      control: FTextFieldControl.managed(
                        onChange: (value) => _email = value.text,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    FTextField(
                      label: const Text('Phone Number'),
                      hint: 'Enter phone number',
                      keyboardType: TextInputType.phone,
                      control: FTextFieldControl.managed(
                        onChange: (value) => _phone = value.text,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Gender Selection
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
                        _SelectionOption(
                          label: 'Male',
                          icon: FIcons.user,
                          isSelected: _gender == 'Male',
                          onTap: () => setState(() => _gender = 'Male'),
                        ),
                        const SizedBox(width: 12),
                        _SelectionOption(
                          label: 'Female',
                          icon: FIcons.user,
                          isSelected: _gender == 'Female',
                          onTap: () => setState(() => _gender = 'Female'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    FTextField(
                      label: const Text('Password'),
                      hint: 'Create a password',
                      obscureText: true,
                      control: FTextFieldControl.managed(
                        onChange: (value) => _password = value.text,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    FButton(
                      onPress: _isLoading ? null : () async {
                        setState(() => _isLoading = true);
                        try {
                          final authService = ref.read(authServiceProvider);
                          final result = await authService.register(
                            username: _username,
                            email: _email,
                            password: _password,
                            firstName: _firstName,
                            lastName: _lastName,
                            phone: _phone,
                            gender: _gender ?? 'Male',
                          );
                          
                          if (result.containsKey('access')) {
                             await ref.read(authStateProvider.notifier).login(
                               result['access'] as String,
                               refreshToken: result['refresh'] as String?,
                             );
                             if (mounted) {
                               _showSuccessModal(context, 'Your account has been created successfully!', () {
                                 // Router will automatically redirect based on user profile
                               });
                             }
                          }
                        } catch (e) {
                          if (mounted) {
                            _showErrorModal(context, _getErrorMessage(e));
                          }
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                      child: _isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Create Account'),
                    ),
                    
                    const SizedBox(height: 32),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: AppColors.textSub,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                    _GoogleButton(
                      isLoading: _isGoogleLoading,
                      onTap: _isGoogleLoading ? null : _signInWithGoogle,
                    ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already Registered? ',
                          style: TextStyle(color: AppColors.textSub, fontSize: 16),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/login'),
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
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
            final message = value is List ? value.join(', ') : value.toString();
            return "${entry.key}: $message";
          }).join('\n');
        }
        if (data.containsKey('error')) return data['error'].toString();
        if (data.containsKey('message')) return data['message'].toString();
      }
      return e.message ?? 'An unexpected error occurred';
    }
    return e.toString();
  }
}

class _SelectionOption extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectionOption({
    required this.label,
    this.icon,
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
          child: Column(
            children: [
              if (icon != null)
                Icon(
                  icon,
                  color: isSelected ? AppColors.accent : AppColors.primary,
                  size: 20,
                ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.accent : AppColors.primary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onTap;

  const _GoogleButton({required this.isLoading, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.textSub.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              const Text(
                'G',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4285F4),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Continue with Google',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
