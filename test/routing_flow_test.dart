// Widget tests for the initial routing flow:
//   Splash (900ms) → Onboarding (최초 실행)
//   Splash (900ms) → Home      (재실행 / onboarding 완료)
//
// SharedPreferences is mocked in-process via setMockInitialValues.
// Hive is initialised with a real temp directory so SplashScreen can open
// the 'notes' box (it checks isBoxOpen first, so we pre-open it).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:samsung_notes_mvp/models/note.dart';
import 'package:samsung_notes_mvp/providers/ads_provider.dart';
import 'package:samsung_notes_mvp/providers/notes_provider.dart';
import 'package:samsung_notes_mvp/providers/purchase_provider.dart';
import 'package:samsung_notes_mvp/providers/settings_provider.dart';
import 'package:samsung_notes_mvp/screens/editor_screen.dart';
import 'package:samsung_notes_mvp/screens/home_screen.dart';
import 'package:samsung_notes_mvp/screens/onboarding_screen.dart';
import 'package:samsung_notes_mvp/screens/settings_screen.dart';
import 'package:samsung_notes_mvp/screens/splash_screen.dart';
import 'package:samsung_notes_mvp/services/purchase_service.dart';

// ---------------------------------------------------------------------------
// Fake PurchaseService (same as in home_responsive_widget_test)
// ---------------------------------------------------------------------------
class _FakePurchaseService extends PurchaseService {
  _FakePurchaseService(SharedPreferences prefs) : super(prefs);

  @override
  Future<void> initialize() async {}

  @override
  void dispose() {
    isPremiumNotifier.dispose();
  }
}

// ---------------------------------------------------------------------------
// Fresh GoRouter for each test (avoids stale navigation state).
// ---------------------------------------------------------------------------
GoRouter _buildRouter() => GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(
          path: '/editor',
          builder: (_, state) =>
              EditorScreen(noteId: state.uri.queryParameters['noteId']),
        ),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
    );

Widget _buildApp(SharedPreferences prefs) {
  final fakeService = _FakePurchaseService(prefs);

  return ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      // noteBoxProvider falls back to the real Hive box opened in setUp.
      purchaseServiceProvider.overrideWith((ref) {
        ref.onDispose(fakeService.dispose);
        return fakeService;
      }),
      bannerAdProvider.overrideWith((ref) => BannerAdNotifier()),
    ],
    child: MaterialApp.router(routerConfig: _buildRouter()),
  );
}

// ---------------------------------------------------------------------------
// Suite
// ---------------------------------------------------------------------------

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('routing_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(NoteAdapter());
    }
  });

  setUp(() async {
    // Pre-open 'notes' box so SplashScreen skips the async openBox() call,
    // leaving only the 900 ms Future.delayed to resolve.
    if (!Hive.isBoxOpen('notes')) {
      await Hive.openBox<Note>('notes');
    }
  });

  tearDown(() async {
    if (Hive.isBoxOpen('notes')) {
      await Hive.box<Note>('notes').clear();
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  // ── 최초 실행: Splash → Onboarding ───────────────────────────────────────

  testWidgets('최초 실행: Splash 화면이 처음 렌더링됨', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_buildApp(prefs));
    // First frame: SplashScreen is visible immediately.
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('최초 실행: 900ms 후 Onboarding으로 이동', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_buildApp(prefs));

    // Advance the fake clock past the 900ms delay in SplashScreen._init().
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('최초 실행: Home은 표시되지 않음', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_buildApp(prefs));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsNothing);
  });

  // ── 재실행: Splash → Home ────────────────────────────────────────────────

  testWidgets('재실행: 900ms 후 Home으로 이동', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_buildApp(prefs));

    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('재실행: Home AppBar 제목 "메모" 표시됨', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_buildApp(prefs));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    expect(find.text('메모'), findsOneWidget);
  });

  // ── Onboarding 완료 → Home 전환 ───────────────────────────────────────────

  testWidgets('Onboarding 완료 버튼 클릭 시 Home으로 이동', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_buildApp(prefs));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    // We are on OnboardingScreen. Tap "시작하기" to complete onboarding.
    // The button text on the last page is "시작하기"; we first navigate to
    // the last page by tapping "다음" twice.
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    // Now on last page (page 2, index 2) — button is "시작하기"
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Onboarding "건너뛰기" 클릭 시 Home으로 이동', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_buildApp(prefs));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);

    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  // ── Splash 타이밍 검증 ────────────────────────────────────────────────────

  testWidgets('500ms 시점에는 아직 Splash에 머무름', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_buildApp(prefs));
    await tester.pump(const Duration(milliseconds: 500));

    // 900ms 지연이 완료되지 않았으므로 Splash 유지.
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });
}
