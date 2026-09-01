import 'package:pdf/pdf.dart';

class PdfTheme {
  final PdfColor primaryColor;
  final PdfColor textColor;
  final PdfColor borderColor;
  final PdfColor lightBg;
  final double margin;

  const PdfTheme({
    required this.primaryColor,
    required this.textColor,
    required this.borderColor,
    required this.lightBg,
    required this.margin,
  });

  static PdfTheme defaultTheme() {
    return const PdfTheme(
      primaryColor: PdfColor.fromInt(0xFF155E63),
      textColor: PdfColor.fromInt(0xFF202124),
      borderColor: PdfColor.fromInt(0xFFE5E7EB),
      lightBg: PdfColor.fromInt(0xFFF8F7F3),
      margin: 24,
    );
  }
}