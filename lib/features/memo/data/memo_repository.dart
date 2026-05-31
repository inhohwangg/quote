import 'package:hive_flutter/hive_flutter.dart';
import 'memo_model.dart';

class MemoRepository {
  static const boxName = 'memos';
  final Box<MemoModel> _box;

  MemoRepository(this._box);

  List<MemoModel> getAll() => (_box.values.toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));

  Future<void> save(MemoModel memo) => _box.put(memo.id, memo);

  Future<void> delete(String id) => _box.delete(id);

  MemoModel? getById(String id) => _box.get(id);

  Future<void> clear() => _box.clear();
}
