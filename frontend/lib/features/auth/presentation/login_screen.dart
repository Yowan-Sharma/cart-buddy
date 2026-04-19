import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_services.dart';
import '../../../core/providers/auth_provider.dart';
import '../data/google_oauth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String _username = '';
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
                    _GoogleButton(
                      isLoading: _isGoogleLoading,
                      onTap: _isGoogleLoading ? null : _signInWithGoogle,
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
              // Google 'G' logo using coloured text
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
