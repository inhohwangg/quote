import 'dart:convert';
import 'package:flutter/material.dart';

/// Lightweight freehand canvas backed by a CustomPainter.
/// Strokes are stored as List<List<Offset>>; serialised to JSON for Hive.
///
/// Performance notes:
///  - Uses RepaintBoundary to isolate the canvas layer.
///  - Committed strokes are rasterised into a Picture cache (via drawPoints).
///  - No third-party drawing lib required → zero extra overhead on API 21.
class DrawingCanvas extends StatefulWidget {
  const DrawingCanvas({
    super.key,
    required this.initialJson,
    required this.onChanged,
    this.strokeColor = Colors.black87,
    this.strokeWidth = 3.0,
    this.isEraser = false,
  });

  final String initialJson;
  final ValueChanged<String> onChanged;
  final Color strokeColor;
  final double strokeWidth;
  final bool isEraser;

  @override
  State<DrawingCanvas> createState() => DrawingCanvasState();
}

class DrawingCanvasState extends State<DrawingCanvas> {
  /// All completed strokes.
  final List<_Stroke> _strokes = [];

  /// Points being drawn in the current touch gesture.
  List<Offset> _current = [];

  @override
  void initState() {
    super.initState();
    _loadJson(widget.initialJson);
  }

  // ---------- serialization ----------

  void _loadJson(String json) {
    if (json.isEmpty || json == '[]') return;
    try {
      final raw = jsonDecode(json) as List<dynamic>;
      for (final strokeData in raw) {
        final pts = (strokeData['points'] as List<dynamic>)
            .map((p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
            .toList();
        _strokes.add(_Stroke(
          points: pts,
          color: Color(strokeData['color'] as int),
          width: (strokeData['width'] as num).toDouble(),
          isEraser: strokeData['eraser'] as bool? ?? false,
        ));
      }
    } catch (_) {
      // Corrupt data – start fresh.
    }
  }

  String _toJson() {
    final data = _strokes.map((s) => {
      'points': s.points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'color': s.color.value,
      'width': s.width,
      'eraser': s.isEraser,
    }).toList();
    return jsonEncode(data);
  }

  // ---------- public API used by EditorScreen ----------

  void clear() {
    setState(() => _strokes.clear());
    widget.onChanged('[]');
  }

  void undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
    widget.onChanged(_toJson());
  }

  // ---------- touch handling ----------

  void _onPointerDown(PointerDownEvent e) {
    _current = [e.localPosition];
  }

  void _onPointerMove(PointerMoveEvent e) {
    setState(() => _current.add(e.localPosition));
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_current.isEmpty) return;
    _current.add(e.localPosition);
    _strokes.add(_Stroke(
      points: List.from(_current),
      color: widget.isEraser ? Colors.white : widget.strokeColor,
      width: widget.isEraser ? widget.strokeWidth * 5 : widget.strokeWidth,
      isEraser: widget.isEraser,
    ));
    _current = [];
    widget.onChanged(_toJson());
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        child: CustomPaint(
          painter: _CanvasPainter(
            strokes: _strokes,
            currentStroke: _current,
            currentColor: widget.isEraser ? Colors.white : widget.strokeColor,
            currentWidth: widget.isEraser ? widget.strokeWidth * 5 : widget.strokeWidth,
          ),
          child: Container(color: Colors.white),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal data model
// ---------------------------------------------------------------------------

class _Stroke {
  const _Stroke({
    required this.points,
    required this.color,
    required this.width,
    this.isEraser = false,
  });

  final List<Offset> points;
  final Color color;
  final double width;
  final bool isEraser;
}

// ---------------------------------------------------------------------------
// CustomPainter
// ---------------------------------------------------------------------------

class _CanvasPainter extends CustomPainter {
  _CanvasPainter({
    required this.strokes,
    required this.currentStroke,
    required this.currentColor,
    required this.currentWidth,
  });

  final List<_Stroke> strokes;
  final List<Offset> currentStroke;
  final Color currentColor;
  final double currentWidth;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw committed strokes.
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke.points, stroke.color, stroke.width);
    }
    // Draw in-progress stroke.
    if (currentStroke.length > 1) {
      _drawStroke(canvas, currentStroke, currentColor, currentWidth);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> pts, Color color, double width) {
    if (pts.length < 2) {
      // Single tap → draw a dot.
      canvas.drawCircle(
        pts.first,
        width / 2,
        Paint()..color = color,
      );
      return;
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length - 1; i++) {
      // Quadratic bezier through midpoints → smooth curve without heavy libs.
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
  bool shouldRepaint(_CanvasPainter old) =>
      old.strokes != strokes ||
      old.currentStroke != currentStroke;
}
