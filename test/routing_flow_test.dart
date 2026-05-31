import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quote/features/memo/data/memo_model.dart';
import 'package:quote/features/memo/data/memo_repository.dart';
import 'package:quote/features/memo/providers/memo_provider.dart';
import 'package:quote/features/onboarding/screens/onboarding_screen.dart';
import 'package:quote/features/onboarding/screens/splash_screen.dart';
import 'package:quote/features/memo/screens/home_screen.dart';
import 'package:quote/core/router/app_router.dart';

class _FakeMemoRepository implements MemoRepository {
  @override List<MemoModel> getAll() => [];
  @override Future<void> save(MemoModel m) async {}
  @override Future<void> delete(String id) async {}
  @override MemoModel? getById(String id) => null;
  @override Future<void> clear() async {}
}

Widget _buildApp() => ProviderScope(
      overrides: [
        memoRepositoryProvider.overrideWithValue(_FakeMemoRepository()),
      ],
      child: MaterialApp.router(routerConfig: AppRouter.router),
    );

void main() {
  group('[라우팅 워크플로우] Splash → Onboarding → Home', () {
    testWidgets('앱 시작 시 SplashScreen 렌더링', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildApp());
      await tester.pump(Duration.zero);
      expect(find.byType(SplashScreen), findsOneWidget);
      // Resolve the pending 2s timer to avoid test framework assertion
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });

    testWidgets('최초 실행(onboarding_done=false): Splash → OnboardingScreen', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('재실행(onboarding_done=true): Splash → HomeScreen', (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_done': true});
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('OnboardingScreen: 다음 버튼 렌더링', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildApp());
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('다음'), findsOneWidget);
    });

    testWidgets('OnboardingScreen: "다음" 2번 탭 후 "시작하기" 표시', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildApp());
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(find.text('시작하기'), findsOneWidget);
    });
  });
}
