import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/note_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('메모'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '검색',
            onPressed: () => _showSearch(context, ref, notes),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      // BannerAdWidget collapses to SizedBox.shrink() when premium or not loaded.
      bottomNavigationBar: const BannerAdWidget(),
      body: notes.isEmpty
          ? const _EmptyState()
          : _ResponsiveNoteList(notes: notes, ref: ref),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNote(context, ref),
        tooltip: '새 메모',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _createNote(BuildContext context, WidgetRef ref) async {
    // Create a persisted (empty) note immediately so EditorScreen always has an ID.
    final note = await ref.read(notesProvider.notifier).createNote();
    if (context.mounted) {
      context.push('/editor?noteId=${note.id}');
    }
  }

  void _showSearch(BuildContext context, WidgetRef ref, List<Note> notes) {
    showSearch(
      context: context,
      delegate: _NoteSearchDelegate(notes: notes, ref: ref),
    );
  }
}

// ---------------------------------------------------------------------------
// Responsive list / grid
// ---------------------------------------------------------------------------

class _ResponsiveNoteList extends StatelessWidget {
  const _ResponsiveNoteList({required this.notes, required this.ref});

  final List<Note> notes;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Breakpoint: 600 dp — phone vs tablet.
        if (constraints.maxWidth >= 600) {
          return _GridView(notes: notes, ref: ref, width: constraints.maxWidth);
        }
        return _ListView(notes: notes, ref: ref);
      },
    );
  }
}

class _ListView extends StatelessWidget {
  const _ListView({required this.notes, required this.ref});

  final List<Note> notes;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _buildCard(ctx, notes[i]),
    );
  }

  Widget _buildCard(BuildContext context, Note note) {
    return NoteCard(
      note: note,
      onTap: () => context.push('/editor?noteId=${note.id}'),
      onDelete: () => ref.read(notesProvider.notifier).deleteNote(note.id),
    );
  }
}

class _GridView extends StatelessWidget {
  const _GridView({
    required this.notes,
    required this.ref,
    required this.width,
  });

  final List<Note> notes;
  final WidgetRef ref;
  final double width;

  @override
  Widget build(BuildContext context) {
    // 2 columns up to 900 dp, 3 columns above.
    final crossCount = width >= 900 ? 3 : 2;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
      itemCount: notes.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        // Fixed aspect ratio keeps card height predictable without measuring.
        childAspectRatio: 0.95,
      ),
      itemBuilder: (ctx, i) => NoteCard(
        note: notes[i],
        onTap: () => ctx.push('/editor?noteId=${notes[i].id}'),
        onDelete: () => ref.read(notesProvider.notifier).deleteNote(notes[i].id),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.note_alt_outlined,
            size: 80,
            color: cs.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            '메모가 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurface.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '아래 + 버튼을 눌러 새 메모를 작성하세요.',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search delegate
// ---------------------------------------------------------------------------

class _NoteSearchDelegate extends SearchDelegate<Note?> {
  _NoteSearchDelegate({required this.notes, required this.ref});

  final List<Note> notes;
  final WidgetRef ref;

  @override
  String get searchFieldLabel => '메모 검색';

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: close);

  void close() => close(context, null);

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final q = query.toLowerCase();
    final filtered = q.isEmpty
        ? notes
        : notes.where((n) {
            return n.displayTitle.toLowerCase().contains(q) ||
                n.content.toLowerCase().contains(q);
          }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('검색 결과 없음'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => NoteCard(
        note: filtered[i],
        onTap: () {
          close(context, filtered[i]);
          context.push('/editor?noteId=${filtered[i].id}');
        },
        onDelete: () {
          ref.read(notesProvider.notifier).deleteNote(filtered[i].id);
          close(context, null);
        },
      ),
    );
  }
}
