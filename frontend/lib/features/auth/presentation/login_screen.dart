import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_services.dart';
import '../../../core/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String _username = '';
  String _password = '';
  bool _isLoading = false;

  void _showErrorModal(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => FDialog(
        title: const Text('Login Failed'),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
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
                    const SizedBox(height: 60),
                    FTextField(
                      label: const Text('Username'),
                      hint: 'Enter your username',
                      control: FTextFieldControl.managed(
                        onChange: (value) => _username = value.text,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FTextField(
                      label: const Text('Password'),
                      hint: 'Enter your password',
                      obscureText: true,
                      control: FTextFieldControl.managed(
                        onChange: (value) => _password = value.text,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // TODO: Implement forgot password
                        },
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FButton(
                      onPress: _isLoading
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              try {
                                final authService = ref.read(
                                  authServiceProvider,
                                );
                                final result = await authService.login(
                                  _username,
                                  _password,
                                );

                                if (result.containsKey('access')) {
                                  ref
                                      .read(authStateProvider.notifier)
                                      .login(
                                        result['access'] as String,
                                        refreshToken: result['refresh'] as String?,
                                      );
                                  if (context.mounted) {
                                    showFToast(
                                      context: context,
                                      title: const Text('Login successful'),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  _showErrorModal(context, _getErrorMessage(e));
                                }
                              } finally {
                                if (mounted) setState(() => _isLoading = false);
                              }
                            },
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Login'),
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
                        _SocialButton(
                          icon:
                              Icons.g_mobiledata, // Placeholder for Google Icon
                          label: 'Google',
                          onTap: () {},
                        ),
                        _SocialButton(
                          icon: Icons.apple,
                          label: 'Apple',
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'New User? ',
                          style: TextStyle(
                            color: AppColors.textSub,
                            fontSize: 16,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/register'),
                          child: const Text(
                            'Create Account',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
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
          return errors.entries
              .map((entry) {
                final value = entry.value;
                final message = value is List
                    ? value.join(', ')
                    : value.toString();
                return "${entry.key}: $message";
              })
              .join('\n');
        }
        if (data.containsKey('error')) return data['error'].toString();
        if (data.containsKey('message')) return data['message'].toString();
      }
      return e.message ?? 'An unexpected error occurred';
    }
    return e.toString();
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.textSub.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
