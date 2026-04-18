import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'core/network/dio_interceptor.dart';
import 'core/providers/auth_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() {
  runApp(const ProviderScope(child: Application()));
}

class Application extends ConsumerStatefulWidget {
  const Application({super.key});

  @override
  ConsumerState<Application> createState() => _ApplicationState();
}

class _ApplicationState extends ConsumerState<Application> {
  @override
  void initState() {
    super.initState();
    AuthInterceptor.onSessionExpired = () async {
      await ref.read(authStateProvider.notifier).logout();
    };
  }

  @override
  void dispose() {
    AuthInterceptor.onSessionExpired = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.light;

    return MaterialApp.router(
      title: 'CartBuddy',
      debugShowCheckedModeBanner: false,
      supportedLocales: FLocalizations.supportedLocales,
      localizationsDelegates: const [...FLocalizations.localizationsDelegates],
      theme: theme.toApproximateMaterialTheme(),
      routerConfig: ref.watch(goRouterProvider),
      builder: (context, child) => FTheme(
        data: theme,
        child: FToaster(child: FTooltipGroup(child: child!)),
      ),
    );
  }
}

class PlaceholderHomeScreen extends StatelessWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader(title: const Text('CartBuddy')),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Welcome to CartBuddy!', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 20),
            FButton(onPress: () {}, child: const Text('Get Started')),
          ],
        ),
      ),
    );
  }
}
