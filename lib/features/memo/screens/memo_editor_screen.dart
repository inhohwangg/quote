import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../data/memo_model.dart';
import '../providers/memo_provider.dart';
import '../widgets/drawing_canvas.dart';
import '../../pdf/pdf_service.dart';

class MemoEditorScreen extends ConsumerStatefulWidget {
  final String? memoId;
  const MemoEditorScreen({super.key, this.memoId});

  @override
  ConsumerState<MemoEditorScreen> createState() => _MemoEditorScreenState();
}

class _MemoEditorScreenState extends ConsumerState<MemoEditorScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  MemoModel? _memo;
  String? _drawingPath;
  List<String> _imagePaths = [];
  bool _showCanvas = false;

  @override
  void initState() {
    super.initState();
    if (widget.memoId != null) {
      final repo = ref.read(memoRepositoryProvider);
      _memo = repo.getById(widget.memoId!);
      if (_memo != null) {
        _titleCtrl.text = _memo!.title;
        _bodyCtrl.text = _memo!.body ?? '';
        _drawingPath = _memo!.drawingPath;
        _imagePaths = List.from(_memo!.imagePaths);
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('제목을 입력해주세요')));
      return;
    }
    final notifier = ref.read(memoListProvider.notifier);
    if (_memo == null) {
      await notifier.add(MemoModel.create(
        title: title,
        body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
        drawingPath: _drawingPath,
        imagePaths: _imagePaths,
      ));
    } else {
      await notifier.update(_memo!.copyWith(
        title: title,
        body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
        drawingPath: _drawingPath,
        imagePaths: _imagePaths,
      ));
    }
    if (mounted) context.go('/home');
  }

  Future<void> _delete() async {
    if (_memo == null) return;
    await ref.read(memoListProvider.notifier).remove(_memo!.id);
    if (mounted) context.go('/home');
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) setState(() => _imagePaths = [..._imagePaths, img.path]);
  }

  Future<void> _saveDrawing(Uint8List pngBytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/drawing_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(pngBytes);
    setState(() {
      _drawingPath = file.path;
      _showCanvas = false;
    });
  }

  Future<void> _exportPdf() async {
    final memo = MemoModel.create(
      title: _titleCtrl.text,
      body: _bodyCtrl.text,
      drawingPath: _drawingPath,
      imagePaths: _imagePaths,
    );
    final doc = await PdfService.generate(memo);
    await Printing.sharePdf(bytes: await doc.save(), filename: '${memo.title}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/home')),
        title: Text(_memo == null ? '새 메모' : '메모 수정'),
        actions: [
          if (_memo != null)
            IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline)),
          IconButton(onPressed: _exportPdf, icon: const Icon(Icons.picture_as_pdf)),
          IconButton(onPressed: _save, icon: const Icon(Icons.check)),
        ],
      ),
      body: _showCanvas
          ? DrawingCanvas(onSave: _saveDrawing)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(hintText: '제목', border: InputBorder.none),
                  ),
                  const Divider(),
                  TextField(
                    controller: _bodyCtrl,
                    maxLines: null,
                    style: const TextStyle(fontSize: 15, height: 1.6),
                    decoration: const InputDecoration(hintText: '내용을 입력하세요', border: InputBorder.none),
                  ),
                  const SizedBox(height: 16),
                  _MediaSection(
                    drawingPath: _drawingPath,
                    imagePaths: _imagePaths,
                    onAddDrawing: () => setState(() => _showCanvas = true),
                    onAddImage: _pickImage,
                    onRemoveImage: (path) => setState(
                        () => _imagePaths = _imagePaths.where((p) => p != path).toList()),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MediaSection extends StatelessWidget {
  final String? drawingPath;
  final List<String> imagePaths;
  final VoidCallback onAddDrawing;
  final VoidCallback onAddImage;
  final Function(String) onRemoveImage;

  const _MediaSection({
    required this.drawingPath,
    required this.imagePaths,
    required this.onAddDrawing,
    required this.onAddImage,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: onAddDrawing,
              icon: const Icon(Icons.draw_outlined, size: 18),
              label: Text(drawingPath != null ? '드로잉 수정' : '드로잉 추가'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onAddImage,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: const Text('이미지 추가'),
            ),
          ],
        ),
        if (drawingPath != null && File(drawingPath!).existsSync()) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(drawingPath!), height: 150, width: double.infinity, fit: BoxFit.cover),
          ),
        ],
        if (imagePaths.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...imagePaths.map((path) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(path), height: 150, width: double.infinity, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => onRemoveImage(path),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }
}
