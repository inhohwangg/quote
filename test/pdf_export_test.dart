import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:quote/features/memo/data/memo_model.dart';
import 'package:quote/features/pdf/pdf_service.dart';

void main() {
  group('[유틸리티 기능] PdfService - 예외 없이 Document 생성', () {
    test('텍스트만 있는 메모 → Document 객체 정상 생성', () async {
      final memo = MemoModel.create(title: '텍스트 메모', body: '본문 내용입니다.');
      final doc = await PdfService.generate(memo);
      expect(doc, isA<pw.Document>());
    });

    test('body 없는 메모 → Document 정상 생성 (NPE 없음)', () async {
      final memo = MemoModel.create(title: '제목만 있는 메모');
      final doc = await PdfService.generate(memo);
      expect(doc, isA<pw.Document>());
    });

    test('imagePaths 포함 메모 → Document 정상 생성', () async {
      final memo = MemoModel.create(title: '이미지 메모', body: '이미지 포함', imagePaths: []);
      final doc = await PdfService.generate(memo);
      expect(doc, isA<pw.Document>());
    });

    test('drawingPath 경로가 있지만 파일 없을 때 → Document 정상 생성 (skip 처리)', () async {
      final memo = MemoModel.create(title: '드로잉 메모', drawingPath: '/nonexistent/drawing.png');
      final doc = await PdfService.generate(memo);
      expect(doc, isA<pw.Document>());
    });

    test('Document의 page 수가 1 이상 (bytes not empty)', () async {
      final memo = MemoModel.create(title: '페이지 확인', body: '내용');
      final doc = await PdfService.generate(memo);
      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('한글·특수문자 제목 메모 → Document 정상 생성', () async {
      final memo = MemoModel.create(title: '"따옴표" & 한글 제목 <태그>', body: '특수문자 본문: @#\$%');
      final doc = await PdfService.generate(memo);
      expect(doc, isA<pw.Document>());
    });
  });
}
