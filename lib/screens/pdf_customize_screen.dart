import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/document.dart';
import '../models/document_item.dart';
import '../services/pdf/pdf_document_builder.dart';
import '../utils/pdf_settings.dart';
import '../utils/print_settings.dart';

/// Settings → Document design. Every change is saved immediately and shown
/// in a live preview built from the business profile and a sample invoice.
class PdfCustomizeScreen extends StatefulWidget {
  const PdfCustomizeScreen({super.key});

  @override
  State<PdfCustomizeScreen> createState() => _PdfCustomizeScreenState();
}

class _PdfCustomizeScreenState extends State<PdfCustomizeScreen> {
  PdfStyleSettings _style = const PdfStyleSettings();
  PaperSize _paper = PaperSize.a4;
  Business? _business;
  bool _loading = true;
  final _footerCtrl = TextEditingController();
  Timer? _footerDebounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _footerDebounce?.cancel();
    _footerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final (style, paper) = await PdfSettings.loadAll();
    final business = await DatabaseHelper.instance.getFirstBusiness();
    if (!mounted) return;
    setState(() {
      _style = style;
      _paper = paper;
      _business = business;
      _footerCtrl.text = style.footerText;
      _loading = false;
    });
  }

  Future<void> _update(PdfStyleSettings style) async {
    setState(() => _style = style);
    await PdfSettings.save(style);
  }

  Future<void> _setPaper(PaperSize size) async {
    setState(() => _paper = size);
    await PrintSettings.setDefaultSize(size);
  }

  Future<void> _reset() async {
    await PdfSettings.reset();
    _footerCtrl.clear();
    setState(() => _style = const PdfStyleSettings());
  }

  Business get _previewBusiness =>
      _business ??
      const Business(
        name: 'ورقتك',
        ownerName: '',
        phone: '+249 900 000 000',
        address: 'الخرطوم',
      );

  Future<Uint8List> _buildPreview(AppLocalizations l10n) {
    final business = _previewBusiness;
    final now = DateTime.now();
    final items = [
      DocumentItem(
          documentId: 0,
          description: l10n.pdfSampleItem1,
          quantity: 1,
          price: 150000,
          total: 150000),
      DocumentItem(
          documentId: 0,
          description: l10n.pdfSampleItem2,
          quantity: 3,
          price: 12500,
          total: 37500),
    ];
    const subtotal = 187500.0;
    final doc = Document(
      type: 'invoice',
      documentNumber: 'INV-0001',
      date: now,
      recipientName: l10n.pdfSampleCustomer,
      recipientPhone: '0912345678',
      subtotal: subtotal,
      discount: 0,
      taxRate: 0,
      taxAmount: 0,
      total: subtotal,
      paid: 100000,
      remaining: subtotal - 100000,
      notes: l10n.pdfSampleNotes,
      currencyCode: business.currencyCode,
    );
    return PdfDocumentBuilder.build(
      doc: doc,
      business: business,
      items: items,
      l10n: l10n,
      paperSize: _paper,
      style: _style,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final preview = _PreviewPane(
      // Rebuild the preview whenever a setting changes.
      key: ValueKey('${_style.hashCode}-${_paper.name}-${l10n.langCode}'),
      buildPdf: () => _buildPreview(l10n),
    );
    final options = _OptionsList(
      l10n: l10n,
      style: _style,
      paper: _paper,
      footerCtrl: _footerCtrl,
      onChanged: _update,
      onPaperChanged: _setPaper,
      onFooterChanged: (text) {
        _footerDebounce?.cancel();
        _footerDebounce = Timer(const Duration(milliseconds: 500),
            () => _update(_style.copyWith(footerText: text)));
      },
    );

    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pdfCustomize),
        actions: [
          IconButton(
            tooltip: l10n.pdfResetDefaults,
            icon: const Icon(Icons.restart_alt),
            onPressed: _reset,
          ),
        ],
      ),
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 420, child: options),
                const VerticalDivider(width: 1),
                Expanded(child: preview),
              ],
            )
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(tabs: [
                    Tab(icon: const Icon(Icons.tune), text: l10n.pdfCustomize),
                    Tab(
                        icon: const Icon(Icons.visibility_outlined),
                        text: l10n.pdfPreview),
                  ]),
                  Expanded(
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [options, preview],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PreviewPane extends StatelessWidget {
  final Future<Uint8List> Function() buildPdf;
  const _PreviewPane({super.key, required this.buildPdf});

  @override
  Widget build(BuildContext context) {
    return PdfPreview(
      build: (_) => buildPdf(),
      useActions: false,
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
      allowPrinting: false,
      allowSharing: false,
      pdfPreviewPageDecoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
          ),
        ],
      ),
      scrollViewDecoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }
}

class _OptionsList extends StatelessWidget {
  final AppLocalizations l10n;
  final PdfStyleSettings style;
  final PaperSize paper;
  final TextEditingController footerCtrl;
  final ValueChanged<PdfStyleSettings> onChanged;
  final ValueChanged<PaperSize> onPaperChanged;
  final ValueChanged<String> onFooterChanged;

  const _OptionsList({
    required this.l10n,
    required this.style,
    required this.paper,
    required this.footerCtrl,
    required this.onChanged,
    required this.onPaperChanged,
    required this.onFooterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget section(String title) => Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 8),
          child: Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                  fontSize: 13)),
        );
    Widget segmented<T>(List<(T, String, IconData?)> values, T selected,
            ValueChanged<T> onSelect) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<T>(
            showSelectedIcon: false,
            segments: [
              for (final v in values)
                ButtonSegment(
                  value: v.$1,
                  label: Text(v.$2, overflow: TextOverflow.ellipsis),
                  icon: v.$3 == null ? null : Icon(v.$3),
                ),
            ],
            selected: {selected},
            onSelectionChanged: (s) => onSelect(s.first),
          ),
        );
    Widget toggle(String title, bool value, PdfStyleSettings Function(bool) f) =>
        SwitchListTile(
          title: Text(title),
          value: value,
          onChanged: (v) => onChanged(f(v)),
        );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        section(l10n.pdfTemplate),
        segmented<PdfTemplate>([
          (PdfTemplate.classic, l10n.pdfTemplateClassic, Icons.article_outlined),
          (PdfTemplate.modern, l10n.pdfTemplateModern, Icons.dashboard_outlined),
          (PdfTemplate.minimal, l10n.pdfTemplateMinimal, Icons.notes),
        ], style.template, (v) => onChanged(style.copyWith(template: v))),

        section(l10n.pdfAccentColor),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in PdfStyleSettings.palette)
                _ColorDot(
                  color: Color(c),
                  selected: style.accentColor == c,
                  onTap: () => onChanged(style.copyWith(accentColor: c)),
                ),
            ],
          ),
        ),

        section(l10n.defaultPaperSize),
        segmented<PaperSize>([
          for (final s in PaperSize.values)
            (s, PrintSettings.labelFor(s, l10n), null),
        ], paper, onPaperChanged),

        section(l10n.pdfLogo),
        segmented<PdfLogoShape>([
          (PdfLogoShape.circle, l10n.pdfLogoCircle, Icons.circle_outlined),
          (PdfLogoShape.rounded, l10n.pdfLogoRounded, Icons.crop_square),
          (PdfLogoShape.hidden, l10n.pdfLogoHidden, Icons.visibility_off_outlined),
        ], style.logoShape, (v) => onChanged(style.copyWith(logoShape: v))),

        section(l10n.pdfTextSize),
        segmented<double>([
          (0.9, l10n.pdfTextSmall, null),
          (1.0, l10n.pdfTextNormal, null),
          (1.12, l10n.pdfTextLarge, null),
        ], PdfStyleSettings.fontScales.contains(style.fontScale) ? style.fontScale : 1.0,
            (v) => onChanged(style.copyWith(fontScale: v))),

        section(l10n.pdfFields),
        toggle(l10n.pdfShowBusinessContact, style.showBusinessContact,
            (v) => style.copyWith(showBusinessContact: v)),
        toggle(l10n.pdfShowTaxId, style.showTaxId,
            (v) => style.copyWith(showTaxId: v)),
        toggle(l10n.pdfShowCustomer, style.showCustomer,
            (v) => style.copyWith(showCustomer: v)),
        toggle(l10n.pdfShowNotes, style.showNotes,
            (v) => style.copyWith(showNotes: v)),
        toggle(l10n.pdfShowPaymentSummary, style.showPaymentSummary,
            (v) => style.copyWith(showPaymentSummary: v)),
        toggle(l10n.pdfZebraRows, style.zebraRows,
            (v) => style.copyWith(zebraRows: v)),
        toggle(l10n.pdfShowSignature, style.showSignature,
            (v) => style.copyWith(showSignature: v)),
        toggle(l10n.pdfShowPageNumbers, style.showPageNumbers,
            (v) => style.copyWith(showPageNumbers: v)),

        section(l10n.pdfFooterText),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: footerCtrl,
            maxLines: 3,
            minLines: 1,
            maxLength: 200,
            decoration: InputDecoration(hintText: l10n.pdfFooterTextHint),
            onChanged: onFooterChanged,
          ),
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ColorDot(
      {required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 3,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}
