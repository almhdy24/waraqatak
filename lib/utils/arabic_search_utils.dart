/// Centralized Arabic search normalization utilities.
///
/// Ensures search queries and in-memory matching treat Arabic letter variants
/// (Alif variants, Taa Marbuta vs Haa, Yaa vs Alif Maqsura) and Tashkeel/Harakat
/// uniformly, while leaving stored values in the database untouched.
class ArabicSearchUtils {
  ArabicSearchUtils._();

  static const _tashkeelRunes = <int>{
    0x064B, // Fathatan
    0x064C, // Dammatan
    0x064D, // Kasratan
    0x064E, // Fatha
    0x064F, // Damma
    0x0650, // Kasra
    0x0651, // Shadda
    0x0652, // Sukun
    0x0640, // Tatweel / Kashida
    0x0670, // Superscript Alef / Dagger Alif
    0x0653, // Maddah above
    0x0654, // Hamza above
    0x0655, // Hamza below
  };

  /// Normalizes Arabic text for comparison/searching:
  /// - Strips Tashkeel, Harakat, Tatweel, and combining marks
  /// - Unifies Alif variants (أ, إ, آ, ٱ) -> ا
  /// - Unifies Taa Marbuta (ة) -> ه
  /// - Unifies Alif Maqsura (ى) -> ي
  /// - Lowercases English/Latin letters
  /// - Trims redundant whitespace
  static String normalize(String text) {
    if (text.isEmpty) return '';
    final buffer = StringBuffer();

    for (final rune in text.runes) {
      if (_tashkeelRunes.contains(rune)) {
        continue;
      }

      switch (rune) {
        // Alif variants
        case 0x0622: // آ
        case 0x0623: // أ
        case 0x0625: // إ
        case 0x0671: // ٱ
          buffer.write('ا');
          break;

        // Taa Marbuta -> Haa
        case 0x0629: // ة
          buffer.write('ه');
          break;

        // Alif Maqsura -> Yaa
        case 0x0649: // ى
          buffer.write('ي');
          break;

        default:
          buffer.writeCharCode(rune);
          break;
      }
    }

    return buffer.toString().toLowerCase().trim();
  }

  /// Checks whether [source] contains [query] using Arabic normalization.
  static bool matches(String? source, String? query) {
    if (source == null || query == null) return false;
    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty) return true;
    final normalizedSource = normalize(source);
    return normalizedSource.contains(normalizedQuery);
  }

  /// Builds a SQLite REPLACE expression for a text column to match normalized queries.
  /// Unifies Alif variants (أ, إ, آ, ٱ), Taa Marbuta (ة), and Alif Maqsura (ى).
  static String sqlNormalize(String column) {
    return "REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE($column, 'أ', 'ا'), 'إ', 'ا'), 'آ', 'ا'), 'ٱ', 'ا'), 'ة', 'ه'), 'ى', 'ي')";
  }
}
