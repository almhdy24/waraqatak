import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// TrueType font for PDFs that corrects the `pdf` package's Arabic
/// isolated-form fallback.
///
/// When a font has no isolated presentation forms (Tajawal has none), the
/// package maps each isolated code point to the base letter's glyph. Its
/// table maps ي (U+064A) to U+FEEF, which is the isolated *alef maksura* ى;
/// the real isolated ي (U+FEF1) is left unmapped. Shaping still emits
/// U+FEF1 for ي after a non-joining letter ("التجاري"), so that glyph went
/// missing or, combined with other text, made the font subsetter throw
/// ("Bad state: No element") and the whole PDF failed.
class ArabicTtfFont extends pw.TtfFont {
  ArabicTtfFont(super.data);

  @override
  PdfFont buildFont(PdfDocument pdfDocument) {
    final font = super.buildFont(pdfDocument);
    if (font is PdfTtfFont) {
      patchIsolatedForms(font.font.charToGlyphIndexMap);
    }
    return font;
  }

  static const _yeh = 0x064A; // ي
  static const _alefMaksura = 0x0649; // ى
  static const _yehIsolated = 0xFEF1;
  static const _alefMaksuraIsolated = 0xFEEF;

  /// Fixes [map] (code point → glyph index) in place. Glyphs the font
  /// really provides are never replaced.
  static void patchIsolatedForms(Map<int, int> map) {
    final yeh = map[_yeh];
    if (yeh != null && !map.containsKey(_yehIsolated)) {
      map[_yehIsolated] = yeh;
    }
    final maksura = map[_alefMaksura];
    // Only undo the package's wrong fallback (ى isolated → ي glyph); a real
    // U+FEEF glyph in the font is a different glyph and is kept.
    if (maksura != null && yeh != null && map[_alefMaksuraIsolated] == yeh) {
      map[_alefMaksuraIsolated] = maksura;
    }
  }
}
