import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../services/pdf_export_service.dart';
import '../widgets/drawing_canvas.dart';

enum _EditorMode { text, drawing }

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, required this.noteId});

  /// Null ≡ "new note" (but HomeScreen pre-creates one, so this is always set).
  final String? noteId;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late String _drawingJson;
  late Note _note;

  _EditorMode _mode = _EditorMode.text;

  // Drawing toolbar state
  Color _penColor = Colors.black87;
  double _penWidth = 3.0;
  bool _isEraser = false;

  final _canvasKey = GlobalKey<DrawingCanvasState>();

  @override
  void initState() {
    super.initState();
    _note = ref.read(noteBoxProvider).get(widget.noteId ?? '') ??
        Note(
          id: widget.noteId ?? '',
          title: '',
          content: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
    _titleCtrl = TextEditingController(text: _note.title);
    _contentCtrl = TextEditingController(text: _note.content);
    _drawingJson = _note.drawingJson;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  // ---------- persistence ----------

  Future<void> _save() async {
    await ref.read(notesProvider.notifier).saveNote(
          id: _note.id,
          title: _titleCtrl.text,
          content: _contentCtrl.text,
          drawingJson: _drawingJson,
        );
  }

  Future<bool> _onWillPop() async {
    await _save();
    return true;
  }

  // ---------- PDF export ----------

  Future<void> _exportPdf() async {
    await _save(); // Persist latest edits before exporting.
    try {
      await PdfExportService.export(
        title: _titleCtrl.text,
        content: _contentCtrl.text,
        drawingJson: _drawingJson,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF 내보내기 실패: $e')),
        );
      }
    }
  }

  // ---------- UI helpers ----------

  void _toggleMode() {
    setState(() {
      _mode = _mode == _EditorMode.text ? _EditorMode.drawing : _EditorMode.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) await _save();
      },
      child: Scaffold(
        appBar: _buildAppBar(context),
        body: _buildBody(),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () async {
          await _save();
          if (context.mounted) context.go('/home');
        },
      ),
      title: TextField(
        controller: _titleCtrl,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        decoration: const InputDecoration(
          hintText: '제목',
          border: InputBorder.none,
          hintStyle: TextStyle(fontWeight: FontWeight.w400),
        ),
        maxLines: 1,
        textInputAction: TextInputAction.next,
      ),
      actions: [
        // Mode toggle: text ↔ draw
        IconButton(
          icon: Icon(
            _mode == _EditorMode.text ? Icons.draw_outlined : Icons.text_fields,
          ),
          tooltip: _mode == _EditorMode.text ? '드로잉 모드' : '텍스트 모드',
          onPressed: _toggleMode,
        ),
        // PDF export & share
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          tooltip: 'PDF로 내보내기',
          onPressed: _exportPdf,
        ),
        // Manual save
        IconButton(
          icon: const Icon(Icons.save_outlined),
          tooltip: '저장',
          onPressed: () async {
            await _save();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('저장되었습니다.'),
                  duration: Duration(seconds: 1),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        if (_mode == _EditorMode.drawing) _buildDrawingToolbar(),
        Expanded(
          child: _mode == _EditorMode.text
              ? _buildTextEditor()
              : _buildDrawingCanvas(),
        ),
      ],
    );
  }

  // ---------- text editor ----------

  Widget _buildTextEditor() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: TextField(
        controller: _contentCtrl,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        style: const TextStyle(
          fontSize: 15,
          height: 1.65,
        ),
        decoration: const InputDecoration(
          hintText: '내용을 입력하세요…',
          border: InputBorder.none,
        ),
      ),
    );
  }

  // ---------- drawing canvas ----------

  Widget _buildDrawingCanvas() {
    return DrawingCanvas(
      key: _canvasKey,
      initialJson: _drawingJson,
      strokeColor: _penColor,
      strokeWidth: _penWidth,
      isEraser: _isEraser,
      onChanged: (json) => _drawingJson = json,
    );
  }

  Widget _buildDrawingToolbar() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Color swatches
          _ColorSwatch(
            color: Colors.black87,
            selected: _penColor == Colors.black87 && !_isEraser,
            onTap: () => setState(() {
              _penColor = Colors.black87;
              _isEraser = false;
            }),
          ),
          _ColorSwatch(
            color: Colors.blue,
            selected: _penColor == Colors.blue && !_isEraser,
            onTap: () => setState(() {
              _penColor = Colors.blue;
              _isEraser = false;
            }),
          ),
          _ColorSwatch(
            color: Colors.red,
            selected: _penColor == Colors.red && !_isEraser,
            onTap: () => setState(() {
              _penColor = Colors.red;
              _isEraser = false;
            }),
          ),
          _ColorSwatch(
            color: Colors.green,
            selected: _penColor == Colors.green && !_isEraser,
            onTap: () => setState(() {
              _penColor = Colors.green;
              _isEraser = false;
            }),
          ),

          const VerticalDivider(width: 16),

          // Stroke width
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            tooltip: '선 굵기 줄이기',
            onPressed: () => setState(() {
              _penWidth = (_penWidth - 1).clamp(1.0, 12.0);
            }),
          ),
          Text(
            _penWidth.toInt().toString(),
            style: const TextStyle(fontSize: 13),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            tooltip: '선 굵기 키우기',
            onPressed: () => setState(() {
              _penWidth = (_penWidth + 1).clamp(1.0, 12.0);
            }),
          ),

          const Spacer(),

          // Eraser
          IconButton(
            icon: Icon(
              Icons.auto_fix_high,
              color: _isEraser
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: '지우개',
            onPressed: () => setState(() => _isEraser = !_isEraser),
          ),
          // Undo
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: '실행 취소',
            onPressed: () => _canvasKey.currentState?.undo(),
          ),
          // Clear all
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: '전체 지우기',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('전체 지우기'),
                  content: const Text('드로잉을 전부 지울까요?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('지우기',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (ok == true) _canvasKey.currentState?.clear();
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Color swatch button
// ---------------------------------------------------------------------------

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)]
              : null,
        ),
      ),
    );
  }
}
