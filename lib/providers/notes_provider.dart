import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';

const _boxName = 'notes';
const _uuid = Uuid();

/// Provides the opened Hive Box<Note>. Must be opened before use (done in SplashScreen).
final noteBoxProvider = Provider<Box<Note>>(
  (ref) => Hive.box<Note>(_boxName),
);

/// All notes sorted by updatedAt descending (most-recent first).
final notesProvider = StateNotifierProvider<NotesNotifier, List<Note>>(
  (ref) => NotesNotifier(ref.watch(noteBoxProvider)),
);

class NotesNotifier extends StateNotifier<List<Note>> {
  NotesNotifier(this._box) : super([]) {
    _load();
  }

  final Box<Note> _box;

  void _load() {
    final notes = _box.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = notes;
  }

  Future<Note> createNote() async {
    final note = Note(
      id: _uuid.v4(),
      title: '',
      content: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _box.put(note.id, note);
    _load();
    return note;
  }

  Future<void> saveNote({
    required String id,
    required String title,
    required String content,
    required String drawingJson,
  }) async {
    final existing = _box.get(id);
    if (existing == null) return;

    final updated = Note(
      id: id,
      title: title,
      content: content,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      drawingJson: drawingJson,
    );
    await _box.put(id, updated);
    _load();
  }

  Future<void> deleteNote(String id) async {
    await _box.delete(id);
    _load();
  }

  Note? getNote(String id) => _box.get(id);
}

/// Convenience provider: look up a single note by ID (nullable).
final noteByIdProvider = Provider.family<Note?, String>(
  (ref, id) {
    // Re-evaluates whenever the notes list changes.
    ref.watch(notesProvider);
    return ref.read(noteBoxProvider).get(id);
  },
);
