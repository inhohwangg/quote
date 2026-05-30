import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/home_screen.dart';
import '../screens/editor_screen.dart';

final appRouter = GoRouter(
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
    ),
    GoRoute(
      path: '/editor',
      builder: (context, state) {
        // Optional ?noteId=<uuid> query param.
        // Absent → create a new note inside EditorScreen.
        final noteId = state.uri.queryParameters['noteId'];
        return EditorScreen(noteId: noteId);
      },
    ),
  ],
);
