import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

part 'memo_model.g.dart';

@HiveType(typeId: 0)
class MemoModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String title;

  @HiveField(2)
  String? body;

  @HiveField(3)
  String? drawingPath;

  @HiveField(4)
  late List<String> imagePaths;

  @HiveField(5)
  late DateTime createdAt;

  @HiveField(6)
  late DateTime updatedAt;

  MemoModel();

  factory MemoModel.create({
    required String title,
    String? body,
    String? drawingPath,
    List<String>? imagePaths,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    return MemoModel()
      ..id = const Uuid().v4()
      ..title = title
      ..body = body
      ..drawingPath = drawingPath
      ..imagePaths = imagePaths ?? []
      ..createdAt = createdAt ?? now
      ..updatedAt = updatedAt ?? now;
  }

  MemoModel copyWith({
    String? title,
    String? body,
    String? drawingPath,
    List<String>? imagePaths,
  }) =>
      MemoModel()
        ..id = id
        ..title = title ?? this.title
        ..body = body ?? this.body
        ..drawingPath = drawingPath ?? this.drawingPath
        ..imagePaths = imagePaths ?? this.imagePaths
        ..createdAt = createdAt
        ..updatedAt = DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'drawingPath': drawingPath,
        'imagePaths': imagePaths,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory MemoModel.fromJson(Map<String, dynamic> json) => MemoModel()
    ..id = json['id'] as String
    ..title = json['title'] as String
    ..body = json['body'] as String?
    ..drawingPath = json['drawingPath'] as String?
    ..imagePaths = (json['imagePaths'] as List).cast<String>()
    ..createdAt = DateTime.parse(json['createdAt'] as String)
    ..updatedAt = DateTime.parse(json['updatedAt'] as String);
}
