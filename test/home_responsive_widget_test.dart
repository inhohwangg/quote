import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote/features/memo/data/memo_model.dart';
import 'package:quote/features/memo/data/memo_repository.dart';
import 'package:quote/features/memo/providers/memo_provider.dart';
import 'package:quote/features/memo/screens/home_screen.dart';

class _FakeMemoRepository implements MemoRepository {
  final List<MemoModel> _data;
  _FakeMemoRepository([List<MemoModel>? data])
      : _data = data ??
            [
              MemoModel.create(title: '메모1', body: '내용1'),
              MemoModel.create(title: '메모2', body: '내용2'),
              MemoModel.create(title: '메모3'),
            ];

  @override
  List<MemoModel> getAll() => _data;
  @override
  Future<void> save(MemoModel m) async => _data.add(m);
  @override
  Future<void> delete(String id) async => _data.removeWhere((m) => m.id == id);
  @override
  MemoModel? getById(String id) => _data.where((m) => m.id == id).firstOrNull;
  @override
  Future<void> clear() async => _data.clear();
}

Widget _buildApp({List<MemoModel>? memos}) => ProviderScope(
      overrides: [
        memoRepositoryProvider.overrideWithValue(_FakeMemoRepository(memos)),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );

void main() {
  group('[반응형 레이아웃] HomeScreen Widget Test', () {
    testWidgets('[스마트폰 < 600] ListView 렌더링', (tester) async {
      tester.view.physicalSize = const Size(360 * 3.0, 800 * 3.0);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('[태블릿 >= 600] GridView 렌더링', (tester) async {
      tester.view.physicalSize = const Size(800 * 2.0, 1200 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('메모 카드들이 화면에 렌더링됨', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('메모1'), findsOneWidget);
      expect(find.text('메모2'), findsOneWidget);
    });

    testWidgets('빈 목록일 때 empty state 문구 표시', (tester) async {
      await tester.pumpWidget(_buildApp(memos: []));
      await tester.pump();

      expect(find.text('메모가 없습니다'), findsOneWidget);
    });

    testWidgets('FAB 버튼이 렌더링됨', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });
}
