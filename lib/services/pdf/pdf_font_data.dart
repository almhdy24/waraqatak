import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

class PdfFontData {
  PdfFontData._();
  static Future<(ByteData, ByteData)>? _cache;

  /// Caches only the raw bytes. Font objects are created per document.
  static Future<(ByteData regular, ByteData bold)> load() {
    return _cache ??= () async {
      await initializeDateFormatting('en', null);
      final r = await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
      final b = await rootBundle.load('assets/fonts/Tajawal-Bold.ttf');
      return (r, b);
    }();
  }
}
