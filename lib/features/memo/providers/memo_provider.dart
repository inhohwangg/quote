import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/memo_model.dart';
import '../data/memo_repository.dart';

final memoRepositoryProvider = Provider<MemoRepository>((ref) {
  return MemoRepository(Hive.box<MemoModel>(MemoRepository.boxName));
});

class MemoNotifier extends StateNotifier<List<MemoModel>> {
  final MemoRepository _repo;

  MemoNotifier(this._repo) : super(_repo.getAll());

  Future<void> add(MemoModel memo) async {
    await _repo.save(memo);
    state = _repo.getAll();
  }

  Future<void> update(MemoModel memo) async {
    await _repo.save(memo);
    state = _repo.getAll();
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    state = _repo.getAll();
  }
}

final memoListProvider = StateNotifierProvider<MemoNotifier, List<MemoModel>>((ref) {
  return MemoNotifier(ref.watch(memoRepositoryProvider));
});

final selectedMemoProvider = StateProvider<MemoModel?>((ref) => null);
