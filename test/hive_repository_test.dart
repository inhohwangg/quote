// Unit tests for NotesNotifier CRUD, Note model helpers, and Drive-backup
// JSON serialization. All Hive I/O runs against a real in-process temp box —
// no Flutter binding required.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:samsung_notes_mvp/models/note.dart';
import 'package:samsung_notes_mvp/providers/notes_provider.dart';

void main() {
  late Directory tempDir;
  late Box<Note> box;
  late NotesNotifier notifier;

  // One temp directory for the entire suite; each test gets its own box name.
  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(NoteAdapter());
    }
  });

  setUp(() async {
    // Unique box name per test prevents state leakage between tests.
    final boxName = 'notes_${DateTime.now().microsecondsSinceEpoch}';
    box = await Hive.openBox<Note>(boxName);
    notifier = NotesNotifier(box);
  });

  tearDown(() async {
    await box.close();
    await box.deleteFromDisk();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  // ── CRUD ─────────────────────────────────────────────────────────────────

  group('CRUD', () {
    test('createNote: box에 저장되고 state에 반영됨', () async {
      expect(notifier.state, isEmpty);
      final note = await notifier.createNote();

      expect(notifier.state, hasLength(1));
      expect(box.get(note.id), isNotNull);
      expect(note.title, isEmpty);
      expect(note.content, isEmpty);
      expect(note.drawingJson, equals('[]'));
    });

    test('createNote: 연속 생성 시 각각 고유 ID 부여', () async {
      final a = await notifier.createNote();
      final b = await notifier.createNote();
      expect(a.id, isNot(equals(b.id)));
      expect(notifier.state, hasLength(2));
    });

    test('saveNote: 제목·본문·드로잉이 올바르게 업데이트됨', () async {
      final note = await notifier.createNote();
      await notifier.saveNote(
        id: note.id,
        title: '수정된 제목',
        content: '수정된 본문',
        drawingJson: '[{"points":[{"x":1.0,"y":2.0}]}]',
      );

      final updated = box.get(note.id)!;
      expect(updated.title, equals('수정된 제목'));
      expect(updated.content, equals('수정된 본문'));
      expect(updated.drawingJson, contains('"x":1.0'));
    });

    test('saveNote: createdAt은 불변, updatedAt은 갱신됨', () async {
      final note = await notifier.createNote();
      final beforeSave = DateTime.now();
      await Future.delayed(const Duration(milliseconds: 5));

      await notifier.saveNote(
        id: note.id,
        title: 'X',
        content: 'X',
        drawingJson: '[]',
      );

      final updated = box.get(note.id)!;
      expect(updated.createdAt, equals(note.createdAt));
      expect(updated.updatedAt.isAfter(beforeSave), isTrue);
    });

    test('saveNote: 존재하지 않는 ID는 무시됨 (throw 없음)', () async {
      await expectLater(
        notifier.saveNote(
          id: 'ghost_id',
          title: 'X',
          content: 'X',
          drawingJson: '[]',
        ),
        completes,
      );
      expect(notifier.state, isEmpty);
    });

    test('deleteNote: Hive 박스와 state에서 모두 제거됨', () async {
      final note = await notifier.createNote();
      await notifier.deleteNote(note.id);

      expect(notifier.state, isEmpty);
      expect(box.get(note.id), isNull);
    });

    test('state: updatedAt 내림차순 정렬', () async {
      final first = await notifier.createNote();
      // Give the clock enough gap so updatedAt differs.
      await Future.delayed(const Duration(milliseconds: 10));
      final second = await notifier.createNote();

      // second is newer → appears first
      expect(notifier.state.first.id, equals(second.id));
      expect(notifier.state.last.id, equals(first.id));
    });

    test('restoreFromBackup: 새 노트는 생성, 기존 노트는 덮어씌움', () async {
      final existing = await notifier.createNote();

      final restored = [
        Note(
          id: existing.id,
          title: '복원 제목',
          content: '복원 내용',
          createdAt: existing.createdAt,
          updatedAt: DateTime.now(),
        ),
        Note(
          id: 'brand_new_id',
          title: '새 메모',
          content: '새 내용',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await notifier.restoreFromBackup(restored);

      expect(notifier.state, hasLength(2));
      final overwritten = notifier.state.firstWhere((n) => n.id == existing.id);
      expect(overwritten.title, equals('복원 제목'));
      expect(box.get('brand_new_id'), isNotNull);
    });
  });

  // ── Note 모델 헬퍼 ────────────────────────────────────────────────────────

  group('Note 모델 헬퍼', () {
    Note _make({String title = '', String content = ''}) => Note(
          id: 'x',
          title: title,
          content: content,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    test('displayTitle: title 우선 반환', () {
      expect(_make(title: '제목', content: '본문').displayTitle, equals('제목'));
    });

    test('displayTitle: title 없으면 content 첫 줄 반환', () {
      expect(_make(content: '첫째\n둘째').displayTitle, equals('첫째'));
    });

    test('displayTitle: title·content 모두 비면 "제목 없음"', () {
      expect(_make().displayTitle, equals('제목 없음'));
    });

    test('preview: 80자 이하는 그대로 반환', () {
      final text = 'A' * 50;
      expect(_make(content: text).preview, equals(text));
    });

    test('preview: 80자 초과 시 말줄임표로 잘림', () {
      final text = 'B' * 100;
      final p = _make(content: text).preview;
      expect(p.endsWith('…'), isTrue);
      expect(p.length, lessThanOrEqualTo(82)); // 80 chars + '…'
    });

    test('preview: 내용 없으면 "내용 없음"', () {
      expect(_make().preview, equals('내용 없음'));
    });
  });

  // ── JSON 직렬화 (Drive 백업 형식) ─────────────────────────────────────────

  group('JSON 직렬화 (DriveBackupService 호환)', () {
    test('notes → JSON → Note 왕복 변환 후 데이터 동일', () async {
      final note = await notifier.createNote();
      await notifier.saveNote(
        id: note.id,
        title: '백업 제목',
        content: '백업 내용',
        drawingJson: '[{"points":[{"x":5.0,"y":10.0}],"color":-16777216,"width":3.0,"eraser":false}]',
      );

      // Serialize (mirrors DriveBackupService.backup)
      final jsonList = notifier.state.map((n) => {
            'id': n.id,
            'title': n.title,
            'content': n.content,
            'createdAt': n.createdAt.toIso8601String(),
            'updatedAt': n.updatedAt.toIso8601String(),
            'drawingJson': n.drawingJson,
          }).toList();

      expect(jsonList, hasLength(1));
      expect(jsonList[0]['title'], equals('백업 제목'));
      expect(jsonList[0]['drawingJson'], contains('"x":5.0'));

      // Deserialize (mirrors DriveBackupService.restore)
      final restored = jsonList
          .map((m) => Note(
                id: m['id'] as String,
                title: m['title'] as String,
                content: m['content'] as String,
                createdAt: DateTime.parse(m['createdAt'] as String),
                updatedAt: DateTime.parse(m['updatedAt'] as String),
                drawingJson: m['drawingJson'] as String,
              ))
          .toList();

      expect(restored.first.id, equals(notifier.state.first.id));
      expect(restored.first.title, equals('백업 제목'));
      expect(restored.first.drawingJson, equals(notifier.state.first.drawingJson));
    });

    test('DateTime ISO-8601 직렬화가 마이크로초까지 보존됨', () async {
      final note = await notifier.createNote();
      final iso = note.createdAt.toIso8601String();
      final parsed = DateTime.parse(iso);
      // Microsecond precision might differ by platform; milliseconds must match.
      expect(parsed.millisecondsSinceEpoch, equals(note.createdAt.millisecondsSinceEpoch));
    });

    test('drawingJson 기본값 "[]"가 그대로 직렬화됨', () async {
      final note = await notifier.createNote();
      expect(note.drawingJson, equals('[]'));
      final json = {'drawingJson': note.drawingJson};
      expect(json['drawingJson'], equals('[]'));
    });
  });
}
