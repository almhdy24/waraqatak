import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/app_localizations.dart';

enum PaperSize { a4, a5, thermal80mm }

class PrintSettings {
  static const _key = 'print_paper_size';

  static Future<PaperSize> getDefaultSize() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_key) ?? 'a4';
    return PaperSize.values.firstWhere(
      (e) => e.name == name,
      orElse: () => PaperSize.a4,
    );
  }

  static Future<void> setDefaultSize(PaperSize size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, size.name);
  }

  static PdfPageFormat pageFormatFor(PaperSize size) => switch (size) {
        PaperSize.a4 => PdfPageFormat.a4,
        PaperSize.a5 => PdfPageFormat.a5,
        PaperSize.thermal80mm => PdfPageFormat(
            80 * PdfPageFormat.mm,
            double.infinity,
            marginAll: 4 * PdfPageFormat.mm,
          ),
      };

  static String labelFor(PaperSize size, AppLocalizations l10n) => switch (size) {
        PaperSize.a4 => l10n.paperA4,
        PaperSize.a5 => l10n.paperA5,
        PaperSize.thermal80mm => l10n.paperThermal80,
      };
}
