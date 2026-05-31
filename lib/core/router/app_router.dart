import 'package:go_router/go_router.dart';
import '../../features/memo/screens/home_screen.dart';
import '../../features/memo/screens/memo_editor_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/onboarding/screens/splash_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const MemoEditorScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) => MemoEditorScreen(
              memoId: state.pathParameters['id'],
            ),
          ),
        ],
      ),
    ],
  );
}
