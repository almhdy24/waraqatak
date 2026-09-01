import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfTextUtils {
  /// يكتشف اتجاه النص بناءً على وجود أحرف عربية.
  static pw.TextDirection detectDirection(String text) {
    if (text.isEmpty) return pw.TextDirection.ltr;
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    return arabicRegex.hasMatch(text)
        ? pw.TextDirection.rtl
        : pw.TextDirection.ltr;
  }

  /// يبني نصًا مع اتجاه محدد بناءً على محتواه.
  static pw.Widget directionalText(
    String text, {
    required pw.Font font,
    double fontSize = 12,
    pw.FontWeight fontWeight = pw.FontWeight.normal,
    PdfColor? color,
    pw.TextDirection? fallbackDirection,
  }) {
    final direction = fallbackDirection ?? detectDirection(text);
    return pw.Directionality(
      textDirection: direction,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        ),
      ),
    );
  }
}