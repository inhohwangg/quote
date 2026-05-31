import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../providers/memo_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/memo_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memos     = ref.watch(memoListProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark    = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('메모', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // 다크/라이트 모드 토글 버튼
          IconButton(
            tooltip: isDark ? '라이트 모드로 전환' : '다크 모드로 전환',
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  RotationTransition(turns: anim, child: child),
              child: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                key: ValueKey(isDark),
              ),
            ),
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: memos.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.note_alt_outlined,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.25)),
                  const SizedBox(height: 12),
                  Text(
                    '메모가 없습니다',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            )
          : ResponsiveLayout(
              phone: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: memos.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MemoCard(
                    memo: memos[i],
                    onTap: () => context.go('/home/${memos[i].id}'),
                  ),
                ),
              ),
              tablet: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                ),
                itemCount: memos.length,
                itemBuilder: (_, i) => MemoCard(
                  memo: memos[i],
                  onTap: () => context.go('/home/${memos[i].id}'),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/home/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
