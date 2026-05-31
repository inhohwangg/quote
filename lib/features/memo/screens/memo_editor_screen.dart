import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../data/memo_model.dart';
import '../providers/memo_provider.dart';
import '../../pdf/pdf_service.dart';

// ── 에디터 모드 ────────────────────────────────────────────────────────────

enum _EditorMode { text, pen, eraser }

// ── 획(Stroke) 데이터 ─────────────────────────────────────────────────────

class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final bool isEraser;

  const _Stroke({
    required this.points,
    required this.color,
    required this.width,
    this.isEraser = false,
  });
}

// ── 상수 ──────────────────────────────────────────────────────────────────

const _kLineSpacing = 32.0;
const _kMarginLeft = 56.0;
const _kAccent = Color(0xFF4A90D9);

const _kColors = [
  Color(0xFF1A1A2E),
  Color(0xFF1E40AF),
  Color(0xFFDC2626),
  Color(0xFF16A34A),
  Color(0xFFD97706),
  Color(0xFF7C3AED),
];

const _kWidths = [2.0, 4.0, 7.0, 12.0];

// ── 에디터 화면 ───────────────────────────────────────────────────────────

class MemoEditorScreen extends ConsumerStatefulWidget {
  final String? memoId;
  const MemoEditorScreen({super.key, this.memoId});

  @override
  ConsumerState<MemoEditorScreen> createState() => _MemoEditorScreenState();
}

class _MemoEditorScreenState extends ConsumerState<MemoEditorScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _bodyFocus = FocusNode();
  final _drawingKey = GlobalKey();

  MemoModel? _memo;
  List<String> _imagePaths = [];
  String? _drawingPath;
  ui.Image? _baseImage;

  // 드로잉 상태 (Riverpod StateProvider로 모드 관리)
  _EditorMode _mode = _EditorMode.text;
  Color _penColor = _kColors.first;
  double _penWidth = _kWidths[1];

  final List<_Stroke> _strokes = [];
  List<Offset>? _livePts; // 현재 그리는 중인 점들 (뮤터블, 할당 없음)
  Color? _liveColor;
  double? _liveWidth;
  bool _liveEraser = false;

  // ── 초기화 ──────────────────────────────────────────────────────────────

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
        if (_drawingPath != null) _loadBaseImage();
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  // ── 기존 드로잉 로드 ─────────────────────────────────────────────────────

  Future<void> _loadBaseImage() async {
    final file = File(_drawingPath!);
    if (!file.existsSync()) return;
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _baseImage = frame.image);
  }

  // ── 터치 이벤트 핸들러 ────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails d) {
    _livePts = [d.localPosition];
    _liveColor = _penColor;
    _liveWidth = _penWidth;
    _liveEraser = _mode == _EditorMode.eraser;
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails d) {
    _livePts?.add(d.localPosition);
    setState(() {});
  }

  void _onPanEnd(DragEndDetails _) {
    if (_livePts != null && _livePts!.length >= 2) {
      _strokes.add(_Stroke(
        points: List.from(_livePts!),
        color: _liveColor!,
        width: _liveWidth!,
        isEraser: _liveEraser,
      ));
    }
    _livePts = null;
    setState(() {});
  }

  // ── 드로잉 PNG 캡처 ───────────────────────────────────────────────────────

  Future<String?> _captureDrawing() async {
    if (_strokes.isEmpty && _baseImage == null) return null;
    final boundary =
        _drawingKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return _drawingPath;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return _drawingPath;
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/drawing_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(data.buffer.asUint8List());
    return file.path;
  }

  // ── 저장 / 삭제 ──────────────────────────────────────────────────────────

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('제목을 입력해주세요')));
      return;
    }
    final newDrawingPath = await _captureDrawing();
    final body =
        _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim();
    final notifier = ref.read(memoListProvider.notifier);

    if (_memo == null) {
      await notifier.add(MemoModel.create(
        title: title,
        body: body,
        drawingPath: newDrawingPath,
        imagePaths: _imagePaths,
      ));
    } else {
      await notifier.update(_memo!.copyWith(
        title: title,
        body: body,
        drawingPath: newDrawingPath,
        imagePaths: _imagePaths,
      ));
    }
    if (mounted) context.go('/home');
  }

  Future<void> _delete() async {
    if (_memo == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('메모 삭제'),
        content: const Text('이 메모를 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(memoListProvider.notifier).remove(_memo!.id);
      if (mounted) context.go('/home');
    }
  }

  void _clearDrawing() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('그림 전체 지우기'),
        content: const Text('캔버스의 모든 그림이 삭제됩니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _strokes.clear();
                _livePts = null;
                _baseImage = null;
                _drawingPath = null;
              });
            },
            child:
                const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final img =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() => _imagePaths = [..._imagePaths, img.path]);
    }
  }

  Future<void> _exportPdf() async {
    final newPath = await _captureDrawing();
    final memo = MemoModel.create(
      title: _titleCtrl.text,
      body: _bodyCtrl.text,
      drawingPath: newPath,
      imagePaths: _imagePaths,
    );
    final doc = await PdfService.generate(memo);
    await Printing.sharePdf(
        bytes: await doc.save(), filename: '${memo.title}.pdf');
  }

  // ── 빌드 ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDrawing = _mode != _EditorMode.text;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: Stack(
              children: [
                // Layer 1: 줄 노트 배경 (터치 없음)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _LinedPaperPainter()),
                  ),
                ),

                // Layer 2: 텍스트 + 이미지 (드로잉 모드일 때 이벤트 차단)
                AbsorbPointer(
                  absorbing: isDrawing,
                  child: SingleChildScrollView(
                    physics: isDrawing
                        ? const NeverScrollableScrollPhysics()
                        : const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                        _kMarginLeft, 6, 16, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _titleCtrl,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            height: 1.45,
                            letterSpacing: -0.3,
                          ),
                          decoration: const InputDecoration(
                            hintText: '제목',
                            hintStyle:
                                TextStyle(color: Color(0xFFBBBBBB)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) =>
                              _bodyFocus.requestFocus(),
                        ),
                        TextField(
                          controller: _bodyCtrl,
                          focusNode: _bodyFocus,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 2.0,
                            color: Color(0xFF2D2D2D),
                          ),
                          decoration: const InputDecoration(
                            hintText: '내용을 입력하세요...',
                            hintStyle:
                                TextStyle(color: Color(0xFFBBBBBB)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          maxLines: null,
                        ),
                        if (_imagePaths.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ..._imagePaths
                              .map((path) => _ImageAttachment(
                                    path: path,
                                    onRemove: () => setState(() =>
                                        _imagePaths = _imagePaths
                                            .where((p) => p != path)
                                            .toList()),
                                  )),
                        ],
                      ],
                    ),
                  ),
                ),

                // Layer 3: 드로잉 캔버스 (텍스트 모드일 때 이벤트 무시)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !isDrawing,
                    child: GestureDetector(
                      // ← 핵심 버그 수정: opaque로 터치 누락 방지
                      behavior: HitTestBehavior.opaque,
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: RepaintBoundary(
                        key: _drawingKey,
                        child: CustomPaint(
                          painter: _DrawingPainter(
                            strokes: _strokes,
                            livePts: _livePts,
                            liveColor: _liveColor,
                            liveWidth: _liveWidth,
                            liveEraser: _liveEraser,
                            baseImage: _baseImage,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => context.go('/home'),
        tooltip: '뒤로',
      ),
      title: Text(
        _memo == null ? '새 메모' : '메모 수정',
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A)),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.image_outlined, size: 22),
          onPressed: _pickImage,
          tooltip: '이미지 추가',
        ),
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 22),
          onPressed: _exportPdf,
          tooltip: 'PDF 내보내기',
        ),
        if (_memo != null)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 22),
            onPressed: _delete,
            tooltip: '삭제',
          ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: _kAccent,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('저장',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // ── 드로잉 툴바 ───────────────────────────────────────────────────────────

  Widget _buildToolbar() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
            bottom: BorderSide(
                color: Colors.grey.shade200, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 모드 버튼들
          _ModeBtn(
            icon: Icons.text_fields_rounded,
            label: 'Aa',
            active: _mode == _EditorMode.text,
            activeColor: _kAccent,
            onTap: () {
              setState(() => _mode = _EditorMode.text);
              _bodyFocus.requestFocus();
            },
          ),
          _ModeBtn(
            icon: Icons.draw_rounded,
            label: '펜',
            active: _mode == _EditorMode.pen,
            activeColor: _penColor,
            onTap: () {
              setState(() => _mode = _EditorMode.pen);
              FocusScope.of(context).unfocus();
            },
          ),
          _ModeBtn(
            icon: Icons.auto_fix_normal_rounded,
            label: '지우개',
            active: _mode == _EditorMode.eraser,
            activeColor: _kAccent,
            onTap: () {
              setState(() => _mode = _EditorMode.eraser);
              FocusScope.of(context).unfocus();
            },
          ),

          _vDivider(),

          // 펜 모드: 색상 + 두께
          if (_mode == _EditorMode.pen) ...[
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: _kColors
                      .map((c) => _ColorDot(
                            color: c,
                            selected: _penColor == c,
                            onTap: () =>
                                setState(() => _penColor = c),
                          ))
                      .toList(),
                ),
              ),
            ),
            _vDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: _kWidths
                    .map((w) => _WidthDot(
                          width: w,
                          color: _penColor,
                          selected: _penWidth == w,
                          onTap: () =>
                              setState(() => _penWidth = w),
                        ))
                    .toList(),
              ),
            ),
          ] else if (_mode == _EditorMode.eraser) ...[
            // 지우개 모드: 두께만
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Text('크기',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500)),
                    const SizedBox(width: 8),
                    ...(_kWidths.map((w) => _WidthDot(
                          width: w,
                          color: Colors.grey.shade500,
                          selected: _penWidth == w,
                          onTap: () =>
                              setState(() => _penWidth = w),
                        ))),
                  ],
                ),
              ),
            ),
          ] else
            const Spacer(),

          // 전체 지우기 (드로잉 모드에서만)
          if (_mode != _EditorMode.text)
            IconButton(
              icon: Icon(Icons.layers_clear_rounded,
                  size: 20, color: Colors.grey.shade500),
              onPressed: _clearDrawing,
              tooltip: '전체 지우기',
            ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: Colors.grey.shade200,
      );
}

// ── 툴바 서브 위젯들 ─────────────────────────────────────────────────────────

class _ModeBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _ModeBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 17,
                color: active
                    ? activeColor
                    : Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active
                    ? activeColor
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot(
      {required this.color,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: selected ? 26 : 20,
        height: selected ? 26 : 20,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
      ),
    );
  }
}

class _WidthDot extends StatelessWidget {
  final double width;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _WidthDot({
    required this.width,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = (width * 1.6 + 2).clamp(8.0, 22.0);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade300,
          shape: BoxShape.circle,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 4,
                  )
                ]
              : null,
        ),
      ),
    );
  }
}

class _ImageAttachment extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;

  const _ImageAttachment({required this.path, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Image.file(
              File(path),
              width: double.infinity,
              fit: BoxFit.fitWidth,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Painter: 줄 노트 배경 ────────────────────────────────────────────────────

class _LinedPaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white,
    );

    final linePaint = Paint()
      ..color = const Color(0xFFE3EAF5)
      ..strokeWidth = 0.9;

    var y = _kLineSpacing;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      y += _kLineSpacing;
    }

    // 노트 왼쪽 마진 선 (분홍색)
    canvas.drawLine(
      Offset(_kMarginLeft - 10, 0),
      Offset(_kMarginLeft - 10, size.height),
      Paint()
        ..color = const Color(0xFFFFCDD2)
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_LinedPaperPainter _) => false;
}

// ── Painter: 드로잉 ──────────────────────────────────────────────────────────

class _DrawingPainter extends CustomPainter {
  final List<_Stroke> strokes;
  final List<Offset>? livePts;
  final Color? liveColor;
  final double? liveWidth;
  final bool liveEraser;
  final ui.Image? baseImage;

  const _DrawingPainter({
    required this.strokes,
    required this.livePts,
    required this.liveColor,
    required this.liveWidth,
    required this.liveEraser,
    required this.baseImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 기존 저장된 드로잉 이미지 (편집 시 로드)
    if (baseImage != null) {
      paintImage(
        canvas: canvas,
        rect: Offset.zero & size,
        image: baseImage!,
        fit: BoxFit.fill,
      );
    }

    // 완성된 획들
    for (final stroke in strokes) {
      _draw(canvas, stroke.points, stroke.color, stroke.width,
          stroke.isEraser);
    }

    // 현재 그리는 중인 획
    if (livePts != null && livePts!.length >= 2) {
      _draw(canvas, livePts!, liveColor!, liveWidth!, liveEraser);
    }
  }

  void _draw(Canvas canvas, List<Offset> pts, Color color, double width,
      bool eraser) {
    if (pts.length < 2) {
      // 점 하나만 있으면 원으로 표시
      if (pts.length == 1 && !eraser) {
        canvas.drawCircle(pts.first, width / 2,
            Paint()..color = color..style = PaintingStyle.fill);
      }
      return;
    }

    final paint = Paint()
      ..color = eraser ? Colors.white : color
      ..strokeWidth = eraser ? width * 3.5 : width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // 베지어 곡선으로 부드러운 선
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final mid = Offset(
        (pts[i].dx + pts[i + 1].dx) / 2,
        (pts[i].dy + pts[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DrawingPainter _) => true;
}
