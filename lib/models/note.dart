import 'package:hive/hive.dart';

part 'note.g.dart';

@HiveType(typeId: 0)
class Note extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String title;

  @HiveField(2)
  late String content;

  @HiveField(3)
  late DateTime createdAt;

  @HiveField(4)
  late DateTime updatedAt;

  /// JSON-encoded strokes: List<List<Map<String,double>>>
  /// Each stroke is a list of {x, y} points captured from PointerMove events.
  @HiveField(5)
  late String drawingJson;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.drawingJson = '[]',
  });

  Note copyWith({
    String? title,
    String? content,
    String? drawingJson,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      drawingJson: drawingJson ?? this.drawingJson,
    );
  }

  /// Preview text shown on the home card
  String get preview {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return '내용 없음';
    return trimmed.length > 80 ? '${trimmed.substring(0, 80)}…' : trimmed;
  }

  /// Derived title: first non-empty line of content, or default string
  String get displayTitle {
    if (title.isNotEmpty) return title;
    final firstLine = content.split('\n').firstWhere(
      (l) => l.trim().isNotEmpty,
      orElse: () => '',
    );
    return firstLine.isNotEmpty ? firstLine : '제목 없음';
  }
}
