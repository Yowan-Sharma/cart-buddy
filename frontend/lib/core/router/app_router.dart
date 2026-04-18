import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/onboarding/presentation/university_selection_screen.dart';
import '../../features/onboarding/presentation/delivery_point_selection_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../providers/auth_provider.dart';
import '../../features/auth/presentation/splash_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: null, // Riverpod handles rebuilds
    redirect: (context, state) {
      // Cold start only: refresh token / session bootstrap (see AuthState.isInitializingAuth)
      if (authState.isInitializingAuth) {
        return state.matchedLocation == '/splash' ? null : '/splash';
      }
      
      // If auth is resolved and we are still on splash, redirect away from it
      if (state.matchedLocation == '/splash') {
        return authState.isAuthenticated ? '/orders' : '/login';
      }

      final isAuthenticated = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!isAuthenticated) {
        return isLoggingIn ? null : '/login';
      }

      // If authenticated but no university set, force onboarding
      // Note: check for null or 0 if that's how it's represented
      if (authState.user?.organisation == null) {
        if (state.matchedLocation != '/onboarding/university') {
          return '/onboarding/university';
        }
        return null;
      }

      // If logging in or on university screen but already has university, go to orders
      if (isLoggingIn || state.matchedLocation == '/onboarding/university') {
        return '/orders';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeShell(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/onboarding/university',
        builder: (context, state) => const UniversitySelectionScreen(),
      ),
      GoRoute(
        path: '/onboarding/delivery-point',
        builder: (context, state) => const DeliveryPointSelectionScreen(),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const HomeShell(),
      ),
    ],
  );
});
