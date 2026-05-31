import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../memo/data/memo_model.dart';

class PdfService {
  static Future<pw.Document> generate(MemoModel memo) async {
    final doc = pw.Document();

    final drawingImage = await _loadImage(memo.drawingPath);
    final attachedImages = await _loadImages(memo.imagePaths);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            memo.title,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          if (memo.body != null && memo.body!.isNotEmpty)
            pw.Text(memo.body!, style: const pw.TextStyle(fontSize: 14)),
          if (drawingImage != null) ...[
            pw.SizedBox(height: 16),
            pw.Text('드로잉', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Image(drawingImage, height: 200),
          ],
          if (attachedImages.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text('첨부 이미지', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            ...attachedImages.map(
              (img) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Image(img, height: 200),
              ),
            ),
          ],
        ],
      ),
    );

    return doc;
  }

  static Future<pw.ImageProvider?> _loadImage(String? path) async {
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return pw.MemoryImage(await file.readAsBytes());
  }

  static Future<List<pw.ImageProvider>> _loadImages(List<String> paths) async {
    final results = <pw.ImageProvider>[];
    for (final path in paths) {
      final img = await _loadImage(path);
      if (img != null) results.add(img);
    }
    return results;
  }
}
