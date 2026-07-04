import 'package:go_router/go_router.dart';

import '../features/home/home_view.dart';
import '../features/onboarding/onboarding_view.dart';
import '../features/settings/settings_view.dart';

final kageRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeView()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingView()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsView()),
  ],
);
