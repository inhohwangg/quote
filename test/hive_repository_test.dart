import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:quote/features/memo/data/memo_model.dart';
import 'package:quote/features/memo/data/memo_repository.dart';

void main() {
  late Directory tempDir;
  late Box<MemoModel> box;
  late MemoRepository repo;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
    Hive.registerAdapter(MemoModelAdapter());
  });

  setUp(() async {
    box = await Hive.openBox<MemoModel>('test_memos');
    repo = MemoRepository(box);
  });

  tearDown(() async {
    await box.clear();
    await box.close();
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('test_memos');
    await tempDir.delete(recursive: true);
  });

  group('[로컬 DB 무결성] MemoRepository CRUD', () {
    test('CREATE: 메모 저장 후 getAll에서 조회 가능', () async {
      final memo = MemoModel.create(title: '첫 번째 메모', body: '내용');
      await repo.save(memo);
      expect(repo.getAll().length, 1);
      expect(repo.getAll().first.title, '첫 번째 메모');
    });

    test('READ: getById로 특정 메모 조회', () async {
      final memo = MemoModel.create(title: '조회 테스트');
      await repo.save(memo);
      final found = repo.getById(memo.id);
      expect(found, isNotNull);
      expect(found!.title, '조회 테스트');
    });

    test('UPDATE: copyWith 후 재저장 시 변경 반영', () async {
      final memo = MemoModel.create(title: '원본 제목');
      await repo.save(memo);
      await repo.save(memo.copyWith(title: '수정된 제목'));
      expect(repo.getById(memo.id)!.title, '수정된 제목');
    });

    test('DELETE: 특정 id 삭제 후 목록에서 제거', () async {
      final memo1 = MemoModel.create(title: '메모1');
      final memo2 = MemoModel.create(title: '메모2');
      await repo.save(memo1);
      await repo.save(memo2);
      await repo.delete(memo1.id);
      expect(repo.getAll().length, 1);
      expect(repo.getAll().first.title, '메모2');
    });

    test('getAll: updatedAt 기준 내림차순 정렬', () async {
      final old = MemoModel.create(title: '오래된 메모', updatedAt: DateTime(2024, 1, 1));
      final recent = MemoModel.create(title: '최신 메모', updatedAt: DateTime(2024, 12, 1));
      await repo.save(old);
      await repo.save(recent);
      expect(repo.getAll().first.title, '최신 메모');
    });

    test('존재하지 않는 id 조회 시 null 반환', () {
      expect(repo.getById('nonexistent'), isNull);
    });

    test('clear: 전체 삭제 후 빈 목록 반환', () async {
      await repo.save(MemoModel.create(title: '메모'));
      await repo.clear();
      expect(repo.getAll(), isEmpty);
    });
  });

  group('[로컬 DB 무결성] MemoModel JSON 직렬화', () {
    test('toJson/fromJson 왕복: 모든 필드 무결성', () {
      final memo = MemoModel.create(
        title: '직렬화 테스트',
        body: '본문 내용',
        drawingPath: '/path/drawing.png',
        imagePaths: ['/img1.jpg', '/img2.jpg'],
      );
      final restored = MemoModel.fromJson(memo.toJson());
      expect(restored.id, memo.id);
      expect(restored.title, memo.title);
      expect(restored.body, memo.body);
      expect(restored.drawingPath, memo.drawingPath);
      expect(restored.imagePaths, memo.imagePaths);
      expect(restored.createdAt.toIso8601String(), memo.createdAt.toIso8601String());
    });

    test('toJson: null 필드는 null로 직렬화', () {
      final memo = MemoModel.create(title: '제목만');
      final json = memo.toJson();
      expect(json['body'], isNull);
      expect(json['drawingPath'], isNull);
      expect(json['imagePaths'], isEmpty);
    });

    test('특수문자·한글 포함 데이터 직렬화 무결성', () {
      final memo = MemoModel.create(title: '"따옴표" & <태그>', body: "저자's note");
      final restored = MemoModel.fromJson(memo.toJson());
      expect(restored.title, memo.title);
      expect(restored.body, memo.body);
    });
  });
}
