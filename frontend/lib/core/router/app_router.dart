import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/profile_completion_screen.dart';
import '../../features/onboarding/presentation/university_selection_screen.dart';
import '../../features/onboarding/presentation/delivery_point_selection_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../providers/auth_provider.dart';
import '../../features/auth/presentation/splash_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: null,
    redirect: (context, state) {
      // Cold start: waiting for session bootstrap
      if (authState.isInitializingAuth) {
        return state.matchedLocation == '/splash' ? null : '/splash';
      }

      // Resolved from splash — redirect based on auth state
      if (state.matchedLocation == '/splash') {
        return authState.isAuthenticated ? '/orders' : '/login';
      }

      final isAuthenticated = authState.isAuthenticated;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/register';

      if (!isAuthenticated) {
        return isAuthRoute ? null : '/login';
      }

      // Authenticated — check profile completeness
      final user = authState.user;
      final needsProfileCompletion =
          user != null && (user.phone.isEmpty || user.phone == '0' || user.gender.isEmpty);

      if (needsProfileCompletion && loc != '/profile-completion') {
        return '/profile-completion';
      }

      if (!needsProfileCompletion && loc == '/profile-completion') {
        return '/orders';
      }

      // If no university set, force onboarding
      if (!needsProfileCompletion && user?.organisation == null) {
        if (loc != '/onboarding/university') return '/onboarding/university';
        return null;
      }

      if (isAuthRoute || loc == '/onboarding/university') {
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
        path: '/profile-completion',
        builder: (context, state) => const ProfileCompletionScreen(),
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
