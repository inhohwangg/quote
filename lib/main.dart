import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/hive/hive_init.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/memo/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHive();
  runApp(const ProviderScope(child: MyApp()));
}

// ConsumerWidget으로 변경하여 themeModeProvider 구독
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Memo',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode, // Riverpod 상태로 라이트/다크 전환
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
