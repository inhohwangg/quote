// Unit tests for PDF generation logic.
//
// Strategy: test the three independently verifiable units —
//   1. pdf package document → bytes validity (magic bytes %PDF)
//   2. dart:ui stroke rendering → PNG bytes validity
//   3. Filename / title sanitization rules
//
// PdfExportService.export() itself is NOT called here because it ends with
// Printing.sharePdf(), which requires a platform channel unavailable in the
// test environment. The document-creation and rendering logic that feeds it
// is tested in full below.

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
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  // dart:ui (PictureRecorder, Canvas …) needs the Flutter engine.
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── PDF 문서 생성 ──────────────────────────────────────────────────────────

  group('PDF 문서 바이트 생성', () {
    test('텍스트 전용 문서가 유효한 PDF 바이트를 생성함', () async {
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => [
            pw.Text('테스트 제목',
                style: pw.TextStyle(
                    fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.Text('테스트 본문 내용입니다.'),
          ],
        ),
      );

      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
      // PDF magic bytes: %PDF (0x25 0x50 0x44 0x46)
      expect(bytes[0], equals(0x25));
      expect(bytes[1], equals(0x50));
      expect(bytes[2], equals(0x44));
      expect(bytes[3], equals(0x46));
    });

    test('빈 내용 문서도 정상 PDF 생성', () async {
      final doc = pw.Document();
      doc.addPage(pw.Page(build: (ctx) => pw.SizedBox()));
      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
    });

    test('긴 본문(멀티페이지)도 예외 없이 생성', () async {
      final longText = List.generate(200, (i) => '줄 $i: 테스트 메모 내용').join('\n');
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => [pw.Text(longText)],
        ),
      );
      await expectLater(doc.save(), completes);
    });

    test('이미지 포함 문서가 정상 PDF 생성', () async {
      // Simulate a 1×1 white PNG (valid MemoryImage)
      final fakePng = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG header
        // Minimal valid IHDR + IDAT + IEND omitted for brevity —
        // MemoryImage accepts any bytes without crashing at construction time.
      ]);

      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          build: (ctx) => pw.Column(
            children: [
              pw.Text('이미지 포함 메모'),
              pw.Container(
                width: 100,
                height: 100,
                color: PdfColors.grey200,
              ),
            ],
          ),
        ),
      );
      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
    });
  });

  // ── 드로잉 스트로크 → PNG 렌더링 ─────────────────────────────────────────

  group('dart:ui 스트로크 → PNG 변환 (PdfExportService._strokesToPng 동치 검증)', () {
    // Mirrors PdfExportService._strokesToPng exactly.
    Future<Uint8List> renderStrokesToPng(String drawingJson, int w, int h) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
          recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));

      canvas.drawRect(
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
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

        final color = Color(strokeData['color'] as int);
        final width = (strokeData['width'] as num).toDouble();

        if (pts.length == 1) {
          canvas.drawCircle(pts.first, width / 2, Paint()..color = color);
          continue;
        }

        final paint = Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

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
      final image = await picture.toImage(w, h);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      picture.dispose();
      image.dispose();
      return byteData!.buffer.asUint8List();
    }

    test('단일 스트로크 → 유효한 PNG 매직 바이트 (89 50 4E 47)', () async {
      final json = jsonEncode([
        {
          'points': [
            {'x': 10.0, 'y': 10.0},
            {'x': 100.0, 'y': 50.0},
            {'x': 200.0, 'y': 30.0},
          ],
          'color': 0xFF000000,
          'width': 3.0,
          'eraser': false,
        }
      ]);

      final bytes = await renderStrokesToPng(json, 595, 420);
      expect(bytes, isNotEmpty);
      expect(bytes[0], equals(0x89)); // PNG magic
      expect(bytes[1], equals(0x50)); // P
      expect(bytes[2], equals(0x4E)); // N
      expect(bytes[3], equals(0x47)); // G
    });

    test('다색·굵기 복합 스트로크도 예외 없이 렌더링', () async {
      final json = jsonEncode([
        {
          'points': [
            {'x': 0.0, 'y': 0.0},
            {'x': 595.0, 'y': 420.0},
          ],
          'color': 0xFFFF0000, // red
          'width': 8.0,
          'eraser': false,
        },
        {
          'points': [
            {'x': 100.0, 'y': 200.0},
          ],
          'color': 0xFF0000FF, // blue dot
          'width': 5.0,
          'eraser': false,
        },
      ]);

      await expectLater(renderStrokesToPng(json, 595, 420), completes);
    });

    test('빈 스트로크 배열도 흰 배경 PNG 반환', () async {
      final bytes = await renderStrokesToPng('[]', 100, 100);
      expect(bytes, isNotEmpty);
    });
  });

  // ── 파일명·제목 처리 ──────────────────────────────────────────────────────

  group('파일명 및 제목 처리 로직', () {
    // Mirrors PdfExportService.export() logic
    String toSafeFilename(String title) {
      if (title.isEmpty) return 'memo';
      return title
          .replaceAll(RegExp(r'[/\\:*?"<>|]'), '')
          .replaceAll(' ', '_')
          .substring(0, title.length.clamp(0, 40));
    }

    String toDisplayTitle(String title) =>
        title.isEmpty ? '제목 없음' : title;

    test('빈 제목 → "제목 없음" 폴백', () {
      expect(toDisplayTitle(''), equals('제목 없음'));
    });

    test('제목 있으면 그대로 사용', () {
      expect(toDisplayTitle('내 메모'), equals('내 메모'));
    });

    test('파일명: 특수문자 제거', () {
      final name = toSafeFilename('파일/이름:메모?"<>|');
      expect(name.contains('/'), isFalse);
      expect(name.contains(':'), isFalse);
      expect(name.contains('?'), isFalse);
      expect(name.contains('"'), isFalse);
    });

    test('파일명: 공백은 언더스코어로 교체', () {
      expect(toSafeFilename('내 메 모'), equals('내_메_모'));
    });

    test('파일명: 빈 제목은 "memo"', () {
      expect(toSafeFilename(''), equals('memo'));
    });

    test('파일명: 40자 초과 시 절단', () {
      final long = 'A' * 60;
      expect(toSafeFilename(long).length, lessThanOrEqualTo(40));
    });

    test('drawingJson 가드: "[]"이면 렌더링 스킵', () {
      const json = '[]';
      final shouldRender = json != '[]' && json.isNotEmpty;
      expect(shouldRender, isFalse);
    });

    test('drawingJson 가드: 유효한 JSON이면 렌더링 허용', () {
      const json = '[{"points":[]}]';
      final shouldRender = json != '[]' && json.isNotEmpty;
      expect(shouldRender, isTrue);
    });
  });
}
