import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfTextUtils {
  static final _arabic = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
  );
  static final _bidiControls = RegExp(
    r'[\u200E\u200F\u061C\u202A-\u202E\u2066-\u2069]',
  );

  /// Strips Unicode Bidi control characters (LRM, RLM, ALM, embeddings,
  /// overrides, and isolates) because Tajawal has no glyphs for them,
  /// which causes PDF renderers to produce missing-glyph replacement boxes.
  static String stripBidiIsolates(String text) {
    if (text.isEmpty) return text;
    return text.replaceAll(_bidiControls, '');
  }

  static bool hasArabic(String text) => _arabic.hasMatch(text);

  /// Space-width multiplier for RTL text. The `pdf` package mirrors RTL
  /// words using their ink width instead of their advance width, so letters
  /// whose tail overhangs the glyph box (ر، ا…) swallow the following space.
  static const double rtlWordSpacing = 2.0;

  /// يكتشف اتجاه النص بناءً على وجود أحرف عربية.
  static pw.TextDirection detectDirection(String text) =>
      hasArabic(text) ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  /// يبني نصًا مع اتجاه محدد بناءً على محتواه.
  static pw.Widget directionalText(
    String text, {
    required pw.Font font,
    double fontSize = 12,
    pw.FontWeight fontWeight = pw.FontWeight.normal,
    PdfColor? color,
    pw.TextDirection? fallbackDirection,
  }) {
    final cleanText = stripBidiIsolates(text);
    // Arabic must always be laid out RTL: forcing LTR embeds unshaped
    // letters, which renders them disconnected and reversed (and can corrupt
    // the font subset when the same document also contains shaped Arabic).
    // [fallbackDirection] only applies to text without Arabic letters.
    final direction = hasArabic(cleanText)
        ? pw.TextDirection.rtl
        : (fallbackDirection ?? pw.TextDirection.ltr);
    return pw.Directionality(
      textDirection: direction,
      child: pw.Text(
        cleanText,
        style: pw.TextStyle(
          font: font,
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          // See PdfDocumentBuilder._pageTheme: keeps RTL words separated.
          wordSpacing: direction == pw.TextDirection.rtl
              ? rtlWordSpacing
              : null,
        ),
      ),
    );
  }
}
