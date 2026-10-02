import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'print_settings.dart';

/// Overall look of A4/A5 documents.
enum PdfTemplate {
  /// Business details on top, accent title, bordered tables (original look).
  classic,

  /// Solid accent header band with white business details.
  modern,

  /// No fills, thin rules, lots of white space.
  minimal,
}

enum PdfLogoShape { circle, rounded, hidden }

/// User customisation for generated PDFs. Stored as JSON in
/// SharedPreferences; every field has a default so older/partial values load.
class PdfStyleSettings {
  /// Accent colour as ARGB int, one of [PdfStyleSettings.palette].
  final int accentColor;
  final PdfTemplate template;
  final PdfLogoShape logoShape;

  /// Text scale factor: 0.9 (small), 1.0 (normal), 1.12 (large).
  final double fontScale;

  final bool showBusinessContact;
  final bool showTaxId;
  final bool showCustomer;
  final bool showNotes;
  final bool showPaymentSummary;
  final bool showSignature;
  final bool showPageNumbers;
  final bool zebraRows;

  /// Free text printed at the bottom of every page (e.g. thank-you note,
  /// bank details). Empty means no custom footer.
  final String footerText;

  const PdfStyleSettings({
    this.accentColor = defaultAccent,
    this.template = PdfTemplate.classic,
    this.logoShape = PdfLogoShape.circle,
    this.fontScale = 1.0,
    this.showBusinessContact = true,
    this.showTaxId = true,
    this.showCustomer = true,
    this.showNotes = true,
    this.showPaymentSummary = true,
    this.showSignature = false,
    this.showPageNumbers = true,
    this.zebraRows = true,
    this.footerText = '',
  });

  static const int defaultAccent = 0xFF155E63;

  /// Accent colours offered in the customisation screen.
  static const List<int> palette = [
    0xFF155E63, // teal (brand)
    0xFF1D4ED8, // blue
    0xFF1E3A5F, // navy
    0xFF15803D, // green
    0xFF7F1D1D, // maroon
    0xFF6D28D9, // purple
    0xFFC2410C, // orange
    0xFF374151, // graphite
  ];

  static const List<double> fontScales = [0.9, 1.0, 1.12];

  PdfStyleSettings copyWith({
    int? accentColor,
    PdfTemplate? template,
    PdfLogoShape? logoShape,
    double? fontScale,
    bool? showBusinessContact,
    bool? showTaxId,
    bool? showCustomer,
    bool? showNotes,
    bool? showPaymentSummary,
    bool? showSignature,
    bool? showPageNumbers,
    bool? zebraRows,
    String? footerText,
  }) =>
      PdfStyleSettings(
        accentColor: accentColor ?? this.accentColor,
        template: template ?? this.template,
        logoShape: logoShape ?? this.logoShape,
        fontScale: fontScale ?? this.fontScale,
        showBusinessContact: showBusinessContact ?? this.showBusinessContact,
        showTaxId: showTaxId ?? this.showTaxId,
        showCustomer: showCustomer ?? this.showCustomer,
        showNotes: showNotes ?? this.showNotes,
        showPaymentSummary: showPaymentSummary ?? this.showPaymentSummary,
        showSignature: showSignature ?? this.showSignature,
        showPageNumbers: showPageNumbers ?? this.showPageNumbers,
        zebraRows: zebraRows ?? this.zebraRows,
        footerText: footerText ?? this.footerText,
      );

  Map<String, dynamic> toJson() => {
        'accentColor': accentColor,
        'template': template.name,
        'logoShape': logoShape.name,
        'fontScale': fontScale,
        'showBusinessContact': showBusinessContact,
        'showTaxId': showTaxId,
        'showCustomer': showCustomer,
        'showNotes': showNotes,
        'showPaymentSummary': showPaymentSummary,
        'showSignature': showSignature,
        'showPageNumbers': showPageNumbers,
        'zebraRows': zebraRows,
        'footerText': footerText,
      };

  factory PdfStyleSettings.fromJson(Map<String, dynamic> j) {
    const d = PdfStyleSettings();
    T pick<T>(String k, T fallback) => j[k] is T ? j[k] as T : fallback;
    E pickEnum<E extends Enum>(String k, List<E> values, E fallback) =>
        values.firstWhere((v) => v.name == j[k], orElse: () => fallback);
    final scale = j['fontScale'];
    return PdfStyleSettings(
      accentColor: pick<int>('accentColor', d.accentColor),
      template: pickEnum('template', PdfTemplate.values, d.template),
      logoShape: pickEnum('logoShape', PdfLogoShape.values, d.logoShape),
      fontScale: scale is num ? scale.toDouble().clamp(0.8, 1.3) : d.fontScale,
      showBusinessContact:
          pick<bool>('showBusinessContact', d.showBusinessContact),
      showTaxId: pick<bool>('showTaxId', d.showTaxId),
      showCustomer: pick<bool>('showCustomer', d.showCustomer),
      showNotes: pick<bool>('showNotes', d.showNotes),
      showPaymentSummary:
          pick<bool>('showPaymentSummary', d.showPaymentSummary),
      showSignature: pick<bool>('showSignature', d.showSignature),
      showPageNumbers: pick<bool>('showPageNumbers', d.showPageNumbers),
      zebraRows: pick<bool>('zebraRows', d.zebraRows),
      footerText: pick<String>('footerText', d.footerText),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PdfStyleSettings &&
      jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

/// Loads and saves [PdfStyleSettings]. Paper size stays in [PrintSettings].
class PdfSettings {
  PdfSettings._();

  static const _key = 'pdf_style_settings';

  static Future<PdfStyleSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const PdfStyleSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return PdfStyleSettings.fromJson(decoded);
      }
    } catch (_) {
      // Corrupt value: fall back to defaults rather than breaking PDFs.
    }
    return const PdfStyleSettings();
  }

  static Future<void> save(PdfStyleSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Convenience for callers that need both settings at once.
  static Future<(PdfStyleSettings, PaperSize)> loadAll() async =>
      (await load(), await PrintSettings.getDefaultSize());
}
