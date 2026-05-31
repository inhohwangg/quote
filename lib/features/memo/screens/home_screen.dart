import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../providers/memo_provider.dart';
import '../widgets/memo_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memos = ref.watch(memoListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('메모', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: memos.isEmpty
          ? const Center(
              child: Text('메모가 없습니다',
                  style: TextStyle(fontSize: 16, color: Colors.grey)))
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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
