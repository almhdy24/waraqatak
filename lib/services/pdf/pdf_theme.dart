import 'package:pdf/pdf.dart';

import '../../utils/pdf_settings.dart';

class PdfTheme {
  final PdfColor primaryColor;
  final PdfColor onPrimaryColor;
  final PdfColor textColor;
  final PdfColor mutedTextColor;
  final PdfColor borderColor;
  final PdfColor lightBg;
  final PdfColor dangerColor;
  final double margin;

  /// Multiplier applied to every font size.
  final double scale;
  final PdfStyleSettings style;

  const PdfTheme({
    required this.primaryColor,
    this.onPrimaryColor = PdfColors.white,
    required this.textColor,
    this.mutedTextColor = const PdfColor.fromInt(0xFF6B7280),
    required this.borderColor,
    required this.lightBg,
    this.dangerColor = const PdfColor.fromInt(0xFFD64545),
    required this.margin,
    this.scale = 1.0,
    this.style = const PdfStyleSettings(),
  });

  static PdfTheme defaultTheme() => fromSettings(const PdfStyleSettings());

  static PdfTheme fromSettings(PdfStyleSettings style) {
    final accent = PdfColor.fromInt(style.accentColor);
    return PdfTheme(
      primaryColor: accent,
      textColor: const PdfColor.fromInt(0xFF202124),
      borderColor: const PdfColor.fromInt(0xFFE5E7EB),
      // 7% accent over white: a soft tint that prints well in grey too.
      lightBg: _mix(accent, PdfColors.white, 0.07),
      margin: 24,
      scale: style.fontScale,
      style: style,
    );
  }

  /// Font size [base] scaled by the user's text-size preference.
  double fs(double base) => base * scale;

  static PdfColor _mix(PdfColor a, PdfColor b, double t) => PdfColor(
        a.red * t + b.red * (1 - t),
        a.green * t + b.green * (1 - t),
        a.blue * t + b.blue * (1 - t),
      );
}
