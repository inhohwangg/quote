import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class DrawingCanvas extends StatefulWidget {
  final Function(Uint8List pngBytes) onSave;
  final Color strokeColor;
  final double strokeWidth;

  const DrawingCanvas({
    super.key,
    required this.onSave,
    this.strokeColor = Colors.black,
    this.strokeWidth = 3.0,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _current = [];
  final GlobalKey _repaintKey = GlobalKey();

  Future<void> _captureAndSave() async {
    final boundary = _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data != null) widget.onSave(data.buffer.asUint8List());
  }

  void _clearCanvas() => setState(() {
        _strokes.clear();
        _current = [];
      });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(onPressed: _clearCanvas, icon: const Icon(Icons.clear), tooltip: '지우기'),
            IconButton(onPressed: _captureAndSave, icon: const Icon(Icons.check), tooltip: '저장'),
          ],
        ),
        Expanded(
          child: RepaintBoundary(
            key: _repaintKey,
            child: GestureDetector(
              onPanStart: (d) => setState(() => _current = [d.localPosition]),
              onPanUpdate: (d) => setState(() => _current = [..._current, d.localPosition]),
              onPanEnd: (_) => setState(() {
                _strokes.add(List.from(_current));
                _current = [];
              }),
              child: CustomPaint(
                painter: _StrokePainter(
                  strokes: _strokes,
                  currentStroke: _current,
                  color: widget.strokeColor,
                  strokeWidth: widget.strokeWidth,
                ),
                child: Container(color: Colors.white, width: double.infinity, height: double.infinity),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final Color color;
  final double strokeWidth;

  const _StrokePainter({
    required this.strokes,
    required this.currentStroke,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    void drawStroke(List<Offset> stroke) {
      if (stroke.length < 2) return;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final stroke in strokes) {
      drawStroke(stroke);
    }
    drawStroke(currentStroke);
  }

  @override
  bool shouldRepaint(_StrokePainter old) =>
      old.strokes != strokes || old.currentStroke != currentStroke;
}
