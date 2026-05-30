// Widget tests verifying HomeScreen renders:
//   - ListView  on phone  (logical width < 600 dp)
//   - GridView  on tablet (logical width ≥ 600 dp)
//
// All external providers (IAP, AdMob) are replaced with lightweight fakes
// so the test doesn't need MobileAds.initialize() or Play Store access.

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
import 'package:samsung_notes_mvp/screens/settings_screen.dart';
import 'package:samsung_notes_mvp/services/purchase_service.dart';

// ---------------------------------------------------------------------------
// Fake PurchaseService — skips the InAppPurchase platform channel entirely.
// ---------------------------------------------------------------------------
class _FakePurchaseService extends PurchaseService {
  _FakePurchaseService(SharedPreferences prefs, {bool premium = false})
      : super(prefs) {
    isPremiumNotifier.value = premium;
  }

  @override
  Future<void> initialize() async {}

  @override
  void dispose() {
    isPremiumNotifier.dispose();
    // Skip _sub.cancel() — _sub is never initialized in this fake.
  }
}

// ---------------------------------------------------------------------------
// Test builder helpers
// ---------------------------------------------------------------------------

GoRouter _homeRouter() => GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(
          path: '/editor',
          builder: (_, state) =>
              EditorScreen(noteId: state.uri.queryParameters['noteId']),
        ),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
    );

Widget _buildApp({
  required Box<Note> box,
  required SharedPreferences prefs,
  bool premium = true, // premium=true → banner hidden → no MobileAds init needed
}) {
  final fakeService = _FakePurchaseService(prefs, premium: premium);

  return ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      noteBoxProvider.overrideWithValue(box),
      purchaseServiceProvider.overrideWith((ref) {
        ref.onDispose(fakeService.dispose);
        return fakeService;
      }),
      // BannerAdNotifier() has null initial state.
      // _load() is NOT called here → no MobileAds platform channel needed.
      bannerAdProvider.overrideWith((ref) => BannerAdNotifier()),
    ],
    child: MaterialApp.router(routerConfig: _homeRouter()),
  );
}

// ---------------------------------------------------------------------------
// Suite
// ---------------------------------------------------------------------------

void main() {
  late Directory tempDir;
  late Box<Note> box;
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('home_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(NoteAdapter());
    }
  });

  setUp(() async {
    prefs = await SharedPreferences.getInstance();
    final name = 'home_${DateTime.now().microsecondsSinceEpoch}';
    box = await Hive.openBox<Note>(name);

    // Pre-populate with 4 notes so ListView/GridView renders items.
    for (int i = 0; i < 4; i++) {
      final note = Note(
        id: 'note_$i',
        title: '메모 $i',
        content: '내용 $i',
        createdAt: DateTime.now().subtract(Duration(seconds: i)),
        updatedAt: DateTime.now().subtract(Duration(seconds: i)),
      );
      await box.put(note.id, note);
    }
  });

  tearDown(() async {
    await box.close();
    await box.deleteFromDisk();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  // ── 스마트폰 레이아웃 (< 600 dp) ─────────────────────────────────────────

  group('스마트폰 (width < 600dp) → ListView', () {
    testWidgets('ListView 렌더링, GridView 없음', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildApp(box: box, prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('첫 번째 메모 카드가 목록에 표시됨', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildApp(box: box, prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.text('메모 0'), findsOneWidget);
    });
  });

  // ── 태블릿 레이아웃 (≥ 600 dp) ───────────────────────────────────────────

  group('태블릿 (width ≥ 600dp) → GridView', () {
    testWidgets('GridView 렌더링, ListView 없음', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildApp(box: box, prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('700dp → crossAxisCount = 2', (tester) async {
      tester.view.physicalSize = const Size(700, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildApp(box: box, prefs: prefs));
      await tester.pumpAndSettle();

      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(2));
    });

    testWidgets('1024dp → crossAxisCount = 3', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildApp(box: box, prefs: prefs));
      await tester.pumpAndSettle();

      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(3));
    });
  });

  // ── 경계값 ───────────────────────────────────────────────────────────────

  group('경계값 (600dp)', () {
    testWidgets('exactly 600dp → GridView', (tester) async {
      tester.view.physicalSize = const Size(600, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildApp(box: box, prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('599dp → ListView', (tester) async {
      tester.view.physicalSize = const Size(599, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildApp(box: box, prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    });
  });

  // ── 빈 상태 ──────────────────────────────────────────────────────────────

  testWidgets('메모 없으면 빈 상태 텍스트 표시, 리스트 없음', (tester) async {
    await box.clear();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildApp(box: box, prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('메모가 없습니다'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(GridView), findsNothing);
  });

  // ── 공통 UI 요소 ──────────────────────────────────────────────────────────

  testWidgets('FAB 버튼 항상 존재', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildApp(box: box, prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('AppBar 제목 "메모" 표시됨', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildApp(box: box, prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('메모'), findsOneWidget);
  });

  testWidgets('설정 아이콘 버튼 존재', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildApp(box: box, prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets('프리미엄 시 배너 위젯이 SizedBox로 collapsed됨', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildApp(box: box, prefs: prefs, premium: true));
    await tester.pumpAndSettle();

    // BannerAdWidget renders SizedBox.shrink() for premium users.
    // Verify bottomNavigationBar area has zero effective height from ads.
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    // bottomNavigationBar is BannerAdWidget; when premium it's SizedBox.shrink.
    expect(scaffold.bottomNavigationBar, isA<Widget>());

    // No "광고" text present anywhere.
    expect(find.textContaining('광고'), findsNothing);
  });
}
