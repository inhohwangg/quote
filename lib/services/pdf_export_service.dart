import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart'
    show
        Canvas,
        Color,
        Colors,
        Offset,
        Paint,
        PaintingStyle,
        Path,
        Rect,
        StrokeCap,
        StrokeJoin;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Converts a note (title + text content + drawing strokes) into a PDF
/// and triggers the system share sheet via [Printing.sharePdf].
///
/// Entirely self-contained — no BuildContext required, safe to call from
/// any async context (e.g. AppBar action).
class PdfExportService {
  PdfExportService._();

  static const _canvasW = 595; // A4 width in points ≈ px for rendering
  static const _canvasH = 420; // Drawing preview height

  static Future<void> export({
    required String title,
    required String content,
    required String drawingJson,
  }) async {
    final doc = pw.Document();

    // Render strokes to PNG only when drawing data is present.
    pw.MemoryImage? drawingImage;
    if (drawingJson != '[]' && drawingJson.isNotEmpty) {
      try {
        final bytes = await _strokesToPng(drawingJson, _canvasW, _canvasH);
        drawingImage = pw.MemoryImage(bytes);
      } catch (_) {
        // Non-fatal: drawing omitted from PDF on render failure.
      }
    }

    final displayTitle = title.isEmpty ? '제목 없음' : title;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 42),
        build: (pw.Context ctx) => [
          pw.Text(
            displayTitle,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Divider(thickness: 0.5, color: PdfColors.grey400),
          pw.SizedBox(height: 12),
          if (content.trim().isNotEmpty)
            pw.Text(
              content,
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 3.5),
            ),
          if (drawingImage != null) ...[
            pw.SizedBox(height: 18),
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Image(drawingImage, fit: pw.BoxFit.contain),
            ),
          ],
        ],
      ),
    );

    // Safe filename: Korean + alphanumeric only
    final safeName = title.isEmpty
        ? 'memo'
        : title
            .replaceAll(RegExp(r'[/\\:*?"<>|]'), '')
            .replaceAll(' ', '_')
            .substring(0, title.length.clamp(0, 40));

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: '$safeName.pdf',
    );
  }

  // ---------------------------------------------------------------------------
  // Stroke → PNG via dart:ui PictureRecorder (no additional package needed)
  // ---------------------------------------------------------------------------

  static Future<Uint8List> _strokesToPng(
    String drawingJson,
    int width,
    int height,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    // White background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = Colors.white,
    );

    final raw = jsonDecode(drawingJson) as List<dynamic>;
    for (final strokeData in raw) {
      final pts = (strokeData['points'] as List<dynamic>)
          .map((p) => Offset(
                (p['x'] as num).toDouble(),
                (p['y'] as num).toDouble(),
              ))
          .toList();

      if (pts.isEmpty) continue;

      final strokeColor = Color(strokeData['color'] as int);
      final strokeWidth = (strokeData['width'] as num).toDouble();

      if (pts.length == 1) {
        canvas.drawCircle(pts.first, strokeWidth / 2, Paint()..color = strokeColor);
        continue;
      }

      final paint = Paint()
        ..color = strokeColor
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      // Quadratic Bezier smoothing (mirrors DrawingCanvas logic)
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < pts.length - 1; i++) {
        final mid = Offset(
          (pts[i].dx + pts[i + 1].dx) / 2,
          (pts[i].dy + pts[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
      }
      path.lineTo(pts.last.dx, pts.last.dy);
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    return byteData!.buffer.asUint8List();
  }
}
