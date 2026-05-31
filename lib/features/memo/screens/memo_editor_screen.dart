import 'dart:async';
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

// ════════════════════════════════════════════════════════════════════════════
// Stroke 데이터 모델
// ════════════════════════════════════════════════════════════════════════════

class Stroke {
  final List<Offset> points;
  final Color  color;
  final double width;

  const Stroke({
    required this.points,
    required this.color,
    required this.width,
  });
}

// ════════════════════════════════════════════════════════════════════════════
// 에디터 모드
// ════════════════════════════════════════════════════════════════════════════

enum _EditorMode { text, pen, eraser }

// ════════════════════════════════════════════════════════════════════════════
// 상수
// ════════════════════════════════════════════════════════════════════════════

const _kLineSpacing   = 32.0;
const _kMarginLeft    = 56.0;
const _kEraserRadius  = 24.0;
const _kAccent        = Color(0xFF4A90D9);
const _kHoldMs        = 500;   // 직선 보정 홀드 임계값(ms)
const _kHoldMoveThr   = 3.0;   // 홀드 판정 최소 이동 임계값(px)
const _kPenWidthMin   = 1.0;
const _kPenWidthMax   = 20.0;
const _kPenWidthInit  = 4.0;

const _kColors = [
  Color(0xFF1A1A2E),
  Color(0xFF1E40AF),
  Color(0xFFDC2626),
  Color(0xFF16A34A),
  Color(0xFFD97706),
  Color(0xFF7C3AED),
];

// ════════════════════════════════════════════════════════════════════════════
// MemoEditorScreen
// ════════════════════════════════════════════════════════════════════════════

class MemoEditorScreen extends ConsumerStatefulWidget {
  final String? memoId;
  const MemoEditorScreen({super.key, this.memoId});

  @override
  ConsumerState<MemoEditorScreen> createState() => _MemoEditorScreenState();
}

class _MemoEditorScreenState extends ConsumerState<MemoEditorScreen> {
  // ── 텍스트 컨트롤러 ────────────────────────────────────────────────────────
  final _titleCtrl  = TextEditingController();
  final _bodyCtrl   = TextEditingController();
  final _titleFocus = FocusNode();
  final _bodyFocus  = FocusNode();
  final _drawingKey = GlobalKey();

  // ── 메모 데이터 ─────────────────────────────────────────────────────────────
  MemoModel?   _memo;
  List<String> _imagePaths = [];
  String?      _drawingPath;
  ui.Image?    _baseImage;

  // ── 드로잉 기본 상태 ─────────────────────────────────────────────────────────
  _EditorMode _mode     = _EditorMode.text;
  Color       _penColor = _kColors.first;
  double      _penWidth = _kPenWidthInit;

  final List<Stroke> _strokes = [];
  List<Offset>? _livePts;   // 현재 그리는 중인 점들
  Offset?       _eraserPos; // 지우개 커서

  // ── 직선 자동 보정 상태 ─────────────────────────────────────────────────────
  Timer? _holdTimer;  // 홀드 감지 타이머
  bool   _isHolding = false; // true이면 직선 보정 완료 상태 (시각 피드백용)

  // ── 두께 슬라이더 팝업 ─────────────────────────────────────────────────────
  bool _showWidthSlider = false;

  // hint 표시 조건: 드로잉 모드이거나 strokes 있으면 숨김
  bool get _showHint => _strokes.isEmpty && _mode == _EditorMode.text;

  // ══════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    if (widget.memoId != null) {
      final repo = ref.read(memoRepositoryProvider);
      _memo = repo.getById(widget.memoId!);
      if (_memo != null) {
        _titleCtrl.text = _memo!.title;
        _bodyCtrl.text  = _memo!.body ?? '';
        _drawingPath    = _memo!.drawingPath;
        _imagePaths     = List.from(_memo!.imagePaths);
        if (_drawingPath != null) _loadBaseImage();
      }
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel(); // Timer 반드시 해제
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 드로잉 헬퍼
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadBaseImage() async {
    final file = File(_drawingPath!);
    if (!file.existsSync()) return;
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _baseImage = frame.image);
  }

  // ── 직선 자동 보정 적용 ──────────────────────────────────────────────────────
  // Timer 발화 시 현재 획의 점들을 [시작점, 끝점] 두 개로 단순화
  void _applyAutoStraight() {
    if (!mounted) return;
    if (_livePts == null || _livePts!.length < 2) return;
    setState(() {
      _livePts  = [_livePts!.first, _livePts!.last]; // ← 직선 단순화
      _isHolding = true; // 시각 피드백 플래그
    });
  }

  // ── 터치 이벤트 ─────────────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails d) {
    if (_mode == _EditorMode.pen) {
      // 새 획 시작: 기존 타이머 정리 + 슬라이더 팝업 닫기
      _holdTimer?.cancel();
      _holdTimer = null;
      setState(() {
        _livePts          = [d.localPosition];
        _isHolding        = false;
        _showWidthSlider  = false; // 드로잉 시작 시 팝업 닫기
      });
    } else if (_mode == _EditorMode.eraser) {
      _eraseStrokesAt(d.localPosition);
      setState(() => _eraserPos = d.localPosition);
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_mode == _EditorMode.pen) {
      _livePts?.add(d.localPosition);

      // ──────────────────────────────────────────────────────────────────────
      // 직선 자동 보정 홀드 감지 알고리즘
      //
      // 원리:
      //   이동량 < _kHoldMoveThr px → 정지 상태 → 타이머 시작(최초 1회)
      //   이동량 ≥ _kHoldMoveThr px → 움직임 → 타이머 취소
      //   타이머 발화(_kHoldMs ms) → _applyAutoStraight() 호출 → 직선 변환
      //
      // 성능:
      //   `_holdTimer ??=` 연산자로 중복 Timer 생성 방지 (구형 기기 대응)
      // ──────────────────────────────────────────────────────────────────────
      if (d.delta.distance < _kHoldMoveThr) {
        // 정지: 이미 타이머가 없는 경우에만 생성 (중복 방지)
        _holdTimer ??= Timer(
          const Duration(milliseconds: _kHoldMs),
          _applyAutoStraight,
        );
      } else {
        // 움직임: 타이머 취소 + 홀드 상태 해제
        if (_holdTimer != null) {
          _holdTimer!.cancel();
          _holdTimer = null;
        }
        if (_isHolding) setState(() => _isHolding = false);
      }

      setState(() {});
    } else if (_mode == _EditorMode.eraser) {
      // 획 지우개: 홀드 타이머와 완전히 독립 (충돌 없음)
      _eraseStrokesAt(d.localPosition);
      setState(() => _eraserPos = d.localPosition);
    }
  }

  void _onPanEnd(DragEndDetails _) {
    // 손을 뗄 때 타이머 무조건 정리 (메모리 누수 방지)
    _holdTimer?.cancel();
    _holdTimer = null;

    if (_mode == _EditorMode.pen && _livePts != null) {
      if (_livePts!.length >= 2) {
        _strokes.add(Stroke(
          points: List.from(_livePts!), // 직선 보정 시에도 동일하게 저장
          color:  _penColor,
          width:  _penWidth,
        ));
      }
      _livePts = null;
    }

    setState(() {
      _eraserPos = null;
      _isHolding = false;
    });
  }

  // Stroke Eraser: 반경 내 교차 획 전체 제거
  void _eraseStrokesAt(Offset pos) {
    final before = _strokes.length;
    _strokes.removeWhere(
      (s) => s.points.any((pt) => (pt - pos).distance <= _kEraserRadius),
    );
    if (_strokes.length != before) setState(() {});
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 저장 / 삭제 / 기타 액션
  // ══════════════════════════════════════════════════════════════════════════

  Future<String?> _captureDrawing() async {
    if (_strokes.isEmpty && _baseImage == null) return null;
    final boundary = _drawingKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return _drawingPath;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data  = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return _drawingPath;
    final dir  = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/drawing_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(data.buffer.asUint8List());
    return file.path;
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('제목을 입력해주세요')));
      _titleFocus.requestFocus();
      return;
    }
    final newPath = await _captureDrawing();
    final body    = _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim();
    final notifier = ref.read(memoListProvider.notifier);
    if (_memo == null) {
      await notifier.add(MemoModel.create(
        title: title, body: body,
        drawingPath: newPath, imagePaths: _imagePaths,
      ));
    } else {
      await notifier.update(_memo!.copyWith(
        title: title, body: body,
        drawingPath: newPath, imagePaths: _imagePaths,
      ));
    }
    if (mounted) context.go('/home');
  }

  Future<void> _delete() async {
    if (_memo == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('메모 삭제'),
        content: const Text('이 메모를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(memoListProvider.notifier).remove(_memo!.id);
      if (mounted) context.go('/home');
    }
  }

  Future<void> _pickImage() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img != null) setState(() => _imagePaths = [..._imagePaths, img.path]);
  }

  Future<void> _exportPdf() async {
    final newPath = await _captureDrawing();
    final memo = MemoModel.create(
      title: _titleCtrl.text, body: _bodyCtrl.text,
      drawingPath: newPath, imagePaths: _imagePaths,
    );
    final doc = await PdfService.generate(memo);
    await Printing.sharePdf(
        bytes: await doc.save(), filename: '${memo.title}.pdf');
  }

  void _clearAllDrawing() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('그림 전체 지우기'),
        content: const Text('캔버스의 모든 획이 삭제됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _strokes.clear();
                _livePts = null;
                _eraserPos = null;
                _baseImage = null;
                _drawingPath = null;
              });
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDrawing = _mode != _EditorMode.text;
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: _buildAppBar(cs),
      body: Column(
        children: [
          // 드로잉 툴바
          _buildToolbar(cs, isDark),
          // 두께 슬라이더 팝업 (툴바 바로 아래, 애니메이션 슬라이드)
          _buildWidthSliderPopup(cs, isDark),

          Expanded(
            child: Stack(
              children: [
                // Layer 1: 줄 노트 배경
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _LinedPaperPainter(isDark: isDark),
                    ),
                  ),
                ),

                // Layer 2: 텍스트 영역
                AbsorbPointer(
                  absorbing: isDrawing,
                  child: SingleChildScrollView(
                    physics: isDrawing
                        ? const NeverScrollableScrollPhysics()
                        : const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                        _kMarginLeft, 8, 16, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 제목 입력
                        TextField(
                          controller: _titleCtrl,
                          focusNode: _titleFocus,
                          style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700,
                            height: 1.45, letterSpacing: -0.3,
                            color: cs.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: _showHint ? '제목' : null,
                            hintStyle: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.3)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _bodyFocus.requestFocus(),
                        ),
                        Divider(
                          height: 1, thickness: 0.8,
                          color: cs.onSurface.withValues(alpha: 0.1),
                        ),
                        const SizedBox(height: 4),
                        // 본문 입력
                        TextField(
                          controller: _bodyCtrl,
                          focusNode: _bodyFocus,
                          style: TextStyle(
                            fontSize: 16, height: 2.0,
                            color: cs.onSurface.withValues(alpha: 0.85),
                          ),
                          decoration: InputDecoration(
                            hintText: _showHint ? '내용을 입력하세요...' : null,
                            hintStyle: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.3)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          maxLines: null,
                        ),
                        if (_imagePaths.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ..._imagePaths.map((path) => _ImageAttachment(
                            path: path,
                            onRemove: () => setState(() =>
                              _imagePaths = _imagePaths
                                  .where((p) => p != path).toList()),
                          )),
                        ],
                      ],
                    ),
                  ),
                ),

                // Layer 3: 드로잉 캔버스
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !isDrawing,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart:  _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd:    _onPanEnd,
                      child: RepaintBoundary(
                        key: _drawingKey,
                        child: CustomPaint(
                          painter: _DrawingPainter(
                            strokes:   _strokes,
                            livePts:   _livePts,
                            liveColor: _penColor,
                            liveWidth: _penWidth,
                            eraserPos: _eraserPos,
                            isEraser:  _mode == _EditorMode.eraser,
                            isHolding: _isHolding, // 직선 보정 피드백
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

  // ══════════════════════════════════════════════════════════════════════════
  // AppBar
  // ══════════════════════════════════════════════════════════════════════════

  AppBar _buildAppBar(ColorScheme cs) => AppBar(
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      onPressed: () => context.go('/home'),
    ),
    title: ListenableBuilder(
      listenable: _titleCtrl,
      builder: (_, __) {
        final t = _titleCtrl.text.trim();
        return Text(
          t.isEmpty ? '새 메모' : t,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        );
      },
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.image_outlined, size: 22),
        onPressed: _pickImage, tooltip: '이미지 추가',
      ),
      IconButton(
        icon: const Icon(Icons.picture_as_pdf_outlined, size: 22),
        onPressed: _exportPdf, tooltip: 'PDF 내보내기',
      ),
      if (_memo != null)
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 22),
          onPressed: _delete, tooltip: '삭제',
        ),
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: _kAccent,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            minimumSize: const Size(0, 36),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('저장',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ),
    ],
  );

  // ══════════════════════════════════════════════════════════════════════════
  // 두께 슬라이더 팝업
  // 툴바 아래에서 AnimatedContainer로 부드럽게 슬라이드
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildWidthSliderPopup(ColorScheme cs, bool isDark) {
    final show = _showWidthSlider && _mode == _EditorMode.pen;
    final bg   = isDark ? const Color(0xFF252535) : const Color(0xFFF0F3FA);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: show ? 64 : 0,
      color: bg,
      // SingleChildScrollView로 height 0일 때 자식 렌더 에러 방지
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // 최소 두께 프리뷰
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: _penColor, shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),

                // 슬라이더 (현재 펜 색상 적용)
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.5,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 11),
                      activeTrackColor: _penColor,
                      inactiveTrackColor:
                          _penColor.withValues(alpha: 0.2),
                      thumbColor: _penColor,
                      overlayColor: _penColor.withValues(alpha: 0.12),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 18),
                    ),
                    child: Slider(
                      value: _penWidth,
                      min: _kPenWidthMin,
                      max: _kPenWidthMax,
                      onChanged: (v) => setState(() => _penWidth = v),
                    ),
                  ),
                ),

                const SizedBox(width: 10),
                // 최대 두께 프리뷰
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: _penColor, shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),

                // 현재 수치 레이블
                SizedBox(
                  width: 42,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${_penWidth.round()}',
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        TextSpan(
                          text: 'px',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 드로잉 툴바
  // Overflow Fix: SingleChildScrollView(horizontal) + BouncingScrollPhysics
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildToolbar(ColorScheme cs, bool isDark) {
    final surfaceColor  = isDark ? const Color(0xFF1C1C28) : Colors.white;
    final borderColor   = cs.outline.withValues(alpha: 0.15);
    final inactiveColor = cs.onSurface.withValues(alpha: 0.45);

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            // ── 모드 버튼 ───────────────────────────────────────────────
            _ModeBtn(
              icon: Icons.text_fields_rounded, label: 'Aa',
              active: _mode == _EditorMode.text,
              activeColor: _kAccent, inactiveColor: inactiveColor,
              onTap: () {
                setState(() {
                  _mode = _EditorMode.text;
                  _showWidthSlider = false;
                });
                _bodyFocus.requestFocus();
              },
            ),
            _ModeBtn(
              icon: Icons.draw_rounded, label: '펜',
              active: _mode == _EditorMode.pen,
              activeColor: _penColor, inactiveColor: inactiveColor,
              onTap: () {
                setState(() => _mode = _EditorMode.pen);
                FocusScope.of(context).unfocus();
              },
            ),
            _ModeBtn(
              icon: Icons.auto_fix_normal_rounded, label: '지우개',
              active: _mode == _EditorMode.eraser,
              activeColor: _kAccent, inactiveColor: inactiveColor,
              onTap: () {
                setState(() {
                  _mode = _EditorMode.eraser;
                  _livePts = null;
                  _showWidthSlider = false;
                  _holdTimer?.cancel();
                  _holdTimer = null;
                });
                FocusScope.of(context).unfocus();
              },
            ),

            _vDiv(borderColor),

            // ── 모드별 서브 툴 ──────────────────────────────────────────
            if (_mode == _EditorMode.pen) ...[
              // 색상 팔레트
              ..._kColors.map((c) => _ColorDot(
                color: c, selected: _penColor == c,
                onTap: () => setState(() => _penColor = c),
              )),
              _vDiv(borderColor),

              // ── 펜촉 프리뷰 버튼 (두께 조절 팝업 토글) ─────────────────
              // 현재 색상 + 두께가 실시간 반영된 원형 아이콘
              // 최소 터치 영역 48×48 보장
              _PenNibButton(
                color: _penColor,
                width: _penWidth,
                isPopupOpen: _showWidthSlider,
                onTap: () => setState(
                    () => _showWidthSlider = !_showWidthSlider),
              ),
            ] else if (_mode == _EditorMode.eraser) ...[
              Icon(Icons.radio_button_unchecked_rounded,
                  size: 18, color: inactiveColor),
              const SizedBox(width: 6),
              Text(
                '획 지우개  ·  터치한 획 전체 삭제',
                style: TextStyle(fontSize: 12, color: inactiveColor),
              ),
            ],

            // ── 직선 자동 보정 상태 표시 (홀드 중) ──────────────────────
            if (_isHolding) ...[
              _vDiv(borderColor),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.straighten_rounded,
                        size: 15, color: _kAccent),
                    const SizedBox(width: 4),
                    Text('직선 보정됨',
                        style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: _kAccent,
                        )),
                  ],
                ),
              ),
            ],

            // ── 전체 지우기 ─────────────────────────────────────────────
            if (_mode != _EditorMode.text) ...[
              const SizedBox(width: 4),
              _vDiv(borderColor),
              IconButton(
                icon: Icon(Icons.layers_clear_rounded,
                    size: 20, color: inactiveColor),
                onPressed: _clearAllDrawing,
                tooltip: '전체 지우기',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _vDiv(Color color) => Container(
    width: 1, height: 24,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: color,
  );
}

// ════════════════════════════════════════════════════════════════════════════
// 펜촉 프리뷰 버튼
// - 현재 펜 색상 + 두께를 원형으로 실시간 표시
// - 최소 터치 영역 48×48 보장 (모바일 가이드라인)
// - 팝업 열림 시 테두리로 활성 상태 표시
// ════════════════════════════════════════════════════════════════════════════

class _PenNibButton extends StatelessWidget {
  final Color  color;
  final double width;
  final bool   isPopupOpen;
  final VoidCallback onTap;

  const _PenNibButton({
    required this.color,
    required this.width,
    required this.isPopupOpen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 원 크기: 두께 1~20px → 표시 8~38px 범위로 매핑
    final previewSize = (width * 1.8 + 6).clamp(8.0, 38.0);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width:  48, // 최소 터치 영역 48×48
        height: 48,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width:  previewSize,
            height: previewSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              // 팝업 열림: 강조 테두리 + 강한 그림자
              border: isPopupOpen
                  ? Border.all(color: const Color(0xFF4A90D9), width: 2.5)
                  : Border.all(
                      color: color.withValues(alpha: 0.25), width: 1),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(
                      alpha: isPopupOpen ? 0.55 : 0.22),
                  blurRadius: isPopupOpen ? 10 : 5,
                  spreadRadius: isPopupOpen ? 1 : 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 툴바 서브 위젯
// ════════════════════════════════════════════════════════════════════════════

class _ModeBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     active;
  final Color    activeColor;
  final Color    inactiveColor;
  final VoidCallback onTap;

  const _ModeBtn({
    required this.icon, required this.label,
    required this.active, required this.activeColor,
    required this.inactiveColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? activeColor.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17,
              color: active ? activeColor : inactiveColor),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: active ? activeColor : inactiveColor,
              )),
        ],
      ),
    ),
  );
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool  selected;
  final VoidCallback onTap;

  const _ColorDot({required this.color, required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: selected ? 26 : 20, height: selected ? 26 : 20,
      decoration: BoxDecoration(
        color: color, shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.white : Colors.transparent, width: 2.5,
        ),
        boxShadow: selected
            ? [BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 6, spreadRadius: 1)]
            : null,
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// 이미지 첨부 위젯
// ════════════════════════════════════════════════════════════════════════════

class _ImageAttachment extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;

  const _ImageAttachment({required this.path, required this.onRemove});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          Image.file(File(path), width: double.infinity,
              fit: BoxFit.fitWidth),
          Positioned(
            top: 8, right: 8,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle,
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

// ════════════════════════════════════════════════════════════════════════════
// Layer 1 — 줄 노트 배경 Painter (다크 모드 대응)
// ════════════════════════════════════════════════════════════════════════════

class _LinedPaperPainter extends CustomPainter {
  final bool isDark;
  const _LinedPaperPainter({this.isDark = false});

  Color get _bg     => isDark ? const Color(0xFF1C1C28) : Colors.white;
  Color get _line   => isDark ? const Color(0xFF2A2A3E) : const Color(0xFFE3EAF5);
  Color get _margin => isDark ? const Color(0xFF3D2030) : const Color(0xFFFFCDD2);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _bg);
    final linePaint = Paint()..color = _line..strokeWidth = 0.9;
    var y = _kLineSpacing;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      y += _kLineSpacing;
    }
    canvas.drawLine(
      Offset(_kMarginLeft - 10, 0),
      Offset(_kMarginLeft - 10, size.height),
      Paint()..color = _margin..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_LinedPaperPainter old) => old.isDark != isDark;
}

// ════════════════════════════════════════════════════════════════════════════
// Layer 3 — 드로잉 Painter
//
// isHolding = true 일 때 (직선 보정 완료):
//   현재 획 주위에 은은한 글로우를 추가해 시각적 피드백 제공
// ════════════════════════════════════════════════════════════════════════════

class _DrawingPainter extends CustomPainter {
  final List<Stroke> strokes;
  final List<Offset>? livePts;
  final Color   liveColor;
  final double  liveWidth;
  final Offset? eraserPos;
  final bool    isEraser;
  final bool    isHolding; // 직선 보정 완료 여부
  final ui.Image? baseImage;

  const _DrawingPainter({
    required this.strokes,
    required this.livePts,
    required this.liveColor,
    required this.liveWidth,
    required this.eraserPos,
    required this.isEraser,
    required this.isHolding,
    required this.baseImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 기존 저장 드로잉 이미지
    if (baseImage != null) {
      paintImage(canvas: canvas, rect: Offset.zero & size,
          image: baseImage!, fit: BoxFit.fill);
    }

    // 완성된 획들
    for (final s in strokes) {
      _draw(canvas, s.points, s.color, s.width);
    }

    // 현재 그리는 중인 획 (투명 배경 유지 — Layer 1이 항상 보임)
    if (!isEraser && livePts != null && livePts!.length >= 2) {
      if (isHolding) {
        // 직선 보정 완료 피드백: 외곽 글로우 2단 겹침
        _draw(canvas, livePts!,
            liveColor.withValues(alpha: 0.15), liveWidth + 14);
        _draw(canvas, livePts!,
            liveColor.withValues(alpha: 0.35), liveWidth + 6);
      }
      _draw(canvas, livePts!, liveColor, liveWidth);
    }

    // 지우개 커서 (흰색 획 없음 → 배경 훼손 없음)
    if (isEraser && eraserPos != null) {
      canvas.drawCircle(eraserPos!, _kEraserRadius,
          Paint()
            ..color = Colors.blueGrey.withValues(alpha: 0.15)
            ..style = PaintingStyle.fill);
      canvas.drawCircle(eraserPos!, _kEraserRadius,
          Paint()
            ..color = Colors.blueGrey.shade400
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
    }
  }

  void _draw(Canvas canvas, List<Offset> pts, Color color, double width) {
    if (pts.length < 2) {
      if (pts.length == 1) {
        canvas.drawCircle(pts.first, width / 2,
            Paint()..color = color..style = PaintingStyle.fill);
      }
      return;
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // 직선(점 2개): lineTo로 정확한 직선
    // 곡선(점 多): 베지어 곡선으로 부드럽게
    if (pts.length == 2) {
      canvas.drawLine(pts.first, pts.last, paint);
    } else {
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
  }

  @override
  bool shouldRepaint(_DrawingPainter _) => true;
}
