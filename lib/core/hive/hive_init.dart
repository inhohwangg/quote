import 'package:hive_flutter/hive_flutter.dart';
import '../../features/memo/data/memo_model.dart';
import '../../features/memo/data/memo_repository.dart';

Future<void> initHive() async {
  await Hive.initFlutter();
  Hive.registerAdapter(MemoModelAdapter());
  await Hive.openBox<MemoModel>(MemoRepository.boxName);
}
