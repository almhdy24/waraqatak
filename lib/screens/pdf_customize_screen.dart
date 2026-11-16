import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/document.dart';
import '../models/document_item.dart';
import '../models/digital_seal.dart';
import '../services/digital_seal_storage_service.dart';
import '../services/pdf/pdf_document_builder.dart';
import '../utils/pdf_settings.dart';
import '../utils/print_settings.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/seal_editor_overlay.dart';
import '../core/feature_gate.dart';
import '../services/feature_access.dart';
import '../widgets/pro_upgrade_sheet.dart';

/// Settings → Document design. Live preview built from the business profile
/// and sample invoice, with interactive digital stamp and signature editor.
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

  DigitalSealConfig? _stampConfig;
  DigitalSealConfig? _sigConfig;
  Uint8List? _stampBytes;
  Uint8List? _sigBytes;

  final Map<SealType, Timer> _sealSaveTimers = {};

  int _previewRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (_footerDebounce?.isActive ?? false) {
      _footerDebounce!.cancel();
      PdfSettings.save(_style.copyWith(footerText: _footerCtrl.text));
    }
    for (final e in _sealSaveTimers.entries.toList()) {
      e.value.cancel();
      final cfg = e.key == SealType.stamp ? _stampConfig : _sigConfig;
      if (cfg != null) {
        DatabaseHelper.instance.saveBusinessSealConfig(_businessId, cfg);
      }
    }
    _footerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final (style, paper) = await PdfSettings.loadAll();
    final business = await DatabaseHelper.instance.getFirstBusiness();
    final businessId = business?.id ?? 1;

    DigitalSealConfig? stamp = await DatabaseHelper.instance
        .getBusinessSealConfig(businessId, SealType.stamp);
    DigitalSealConfig? sig = await DatabaseHelper.instance
        .getBusinessSealConfig(businessId, SealType.signature);

    // Initial fallbacks if no config exists in db yet
    stamp ??= const DigitalSealConfig(
      type: SealType.stamp,
      startRatio: 0.55,
      topRatio: 0.82,
      widthRatio: 0.22,
      aspectRatio: 1.0,
      opacity: 0.85,
    );

    sig ??= const DigitalSealConfig(
      type: SealType.signature,
      startRatio: 0.15,
      topRatio: 0.82,
      widthRatio: 0.24,
      aspectRatio: 1.5,
      opacity: 1.0,
    );

    Uint8List? stampBytes;
    if (stamp.assetId != null) {
      final asset = await DatabaseHelper.instance.getDigitalAsset(
        stamp.assetId!,
        businessId: businessId,
      );
      if (asset != null) {
        stampBytes = await DigitalSealStorageService.getAssetBytes(
          asset.filename,
        );
      }
    }

    Uint8List? sigBytes;
    if (sig.assetId != null) {
      final asset = await DatabaseHelper.instance.getDigitalAsset(
        sig.assetId!,
        businessId: businessId,
      );
      if (asset != null) {
        sigBytes = await DigitalSealStorageService.getAssetBytes(
          asset.filename,
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _style = style;
      _paper = paper;
      _business = business;
      _stampConfig = stamp;
      _sigConfig = sig;
      _stampBytes = stampBytes;
      _sigBytes = sigBytes;
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

  int get _businessId => _business?.id ?? 1;

  Future<void> _pickSeal(SealType type) async {
    final l10n = AppLocalizations.of(context);
    DigitalSealAsset? newlySavedAsset;
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw FormatException(l10n.pdfSealUploadFailed);

      final asset = await DigitalSealStorageService.saveAsset(
        businessId: _businessId,
        type: type,
        bytes: bytes,
      );
      newlySavedAsset = asset;
      await DatabaseHelper.instance.insertDigitalAsset(asset);

      final current = type == SealType.stamp ? _stampConfig! : _sigConfig!;
      final oldAssetId = current.assetId;
      final updated = current.copyWith(
        assetId: asset.id,
        aspectRatio: asset.aspectRatio,
        isEnabled: true,
      );

      _sealSaveTimers.remove(type)?.cancel();
      await DatabaseHelper.instance.saveBusinessSealConfig(
        _businessId,
        updated,
      );

      if (oldAssetId != null && oldAssetId != asset.id) {
        await DatabaseHelper.instance.softDeleteDigitalAsset(
          oldAssetId,
          businessId: _businessId,
        );
        await DatabaseHelper.instance.cleanupUnreferencedAssets(
          businessId: _businessId,
        );
      }

      if (!mounted) return;
      setState(() {
        if (type == SealType.stamp) {
          _stampConfig = updated;
          _stampBytes = bytes;
        } else {
          _sigConfig = updated;
          _sigBytes = bytes;
        }
        _previewRefreshKey++;
      });
    } on FormatException catch (e) {
      if (newlySavedAsset != null) {
        await DigitalSealStorageService.deleteAssetFile(newlySavedAsset.filename);
      }
      if (!mounted) return;
      final errorMsg = e.message.contains('10MB')
          ? l10n.pdfSealOversized
          : l10n.pdfSealInvalidOrUnsupported;
      AppSnackBar.show(context, errorMsg, severity: AppSnackBarSeverity.error);
    } on IOException {
      if (newlySavedAsset != null) {
        await DigitalSealStorageService.deleteAssetFile(newlySavedAsset.filename);
      }
      if (!mounted) return;
      AppSnackBar.show(
        context,
        l10n.pdfSealSaveFailed,
        severity: AppSnackBarSeverity.error,
      );
    } catch (_) {
      if (newlySavedAsset != null) {
        await DigitalSealStorageService.deleteAssetFile(newlySavedAsset.filename);
      }
      if (!mounted) return;
      AppSnackBar.show(
        context,
        l10n.pdfSealUploadFailed,
        severity: AppSnackBarSeverity.error,
      );
    }
  }

  Future<void> _removeSeal(SealType type) async {
    final current = type == SealType.stamp ? _stampConfig! : _sigConfig!;
    final assetIdToRemove = current.assetId;

    final updated = current.copyWith(clearAssetId: true, isEnabled: false);

    _sealSaveTimers.remove(type)?.cancel();
    await DatabaseHelper.instance.saveBusinessSealConfig(_businessId, updated);

    if (assetIdToRemove != null) {
      await DatabaseHelper.instance.softDeleteDigitalAsset(
        assetIdToRemove,
        businessId: _businessId,
      );
      // Attempt safe cleanup of unreferenced files
      await DatabaseHelper.instance.cleanupUnreferencedAssets(
        businessId: _businessId,
      );
    }

    if (!mounted) return;
    setState(() {
      if (type == SealType.stamp) {
        _stampConfig = updated;
        _stampBytes = null;
      } else {
        _sigConfig = updated;
        _sigBytes = null;
      }
      _previewRefreshKey++;
    });
  }

  Future<void> _updateSealConfig(DigitalSealConfig config) async {
    setState(() {
      if (config.type == SealType.stamp) {
        _stampConfig = config;
      } else {
        _sigConfig = config;
      }
    });
    _sealSaveTimers[config.type]?.cancel();
    _sealSaveTimers[config.type] = Timer(const Duration(milliseconds: 250), () {
      _sealSaveTimers.remove(config.type);
      DatabaseHelper.instance.saveBusinessSealConfig(_businessId, config);
    });
  }

  Future<void> _resetSealPosition(SealType type) async {
    final current = type == SealType.stamp ? _stampConfig! : _sigConfig!;
    final defaultStart = type == SealType.stamp ? 0.55 : 0.15;
    final updated = current.copyWith(
      startRatio: defaultStart,
      topRatio: 0.82,
      widthRatio: type == SealType.stamp ? 0.22 : 0.24,
    );
    await _updateSealConfig(updated);
    setState(() => _previewRefreshKey++);
  }

  Business get _previewBusiness {
    final l10n = AppLocalizations.of(context);
    return _business ??
        Business(
          name: l10n.appTitle,
          ownerName: '',
          phone: '',
          address: '',
        );
  }

  Future<Uint8List> _buildPreview(AppLocalizations l10n) {
    final business = _previewBusiness;
    final now = DateTime.now();
    final items = [
      DocumentItem(
        documentId: 0,
        description: l10n.pdfSampleItem1,
        quantity: 1,
        price: 150000,
        total: 150000,
      ),
      DocumentItem(
        documentId: 0,
        description: l10n.pdfSampleItem2,
        quantity: 3,
        price: 12500,
        total: 37500,
      ),
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

    final isPro = FeatureGate.isAvailable(Feature.digitalSeals);
    final hasActiveOverlaySeals =
        isPro &&
        _paper != PaperSize.thermal80mm &&
        ((_stampConfig?.isEnabled == true && _stampBytes != null) ||
            (_sigConfig?.isEnabled == true && _sigBytes != null));

    return PdfDocumentBuilder.build(
      doc: doc,
      business: business,
      items: items,
      l10n: l10n,
      paperSize: _paper,
      style: _style,
      activeSealsPreview:
          hasActiveOverlaySeals ? null : (isPro ? (_stampConfig, _sigConfig) : null),
    );
  }

  Future<void> _handleProUpgrade() async {
    final res = await ProUpgradeSheet.show(
      context,
      feature: Feature.digitalSeals,
    );
    if (res == true && mounted) {
      await FeatureGate.refresh(force: true);
      setState(() => _previewRefreshKey++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.pdfCustomize)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isPro = FeatureGate.isAvailable(Feature.digitalSeals);
    final isArabic = l10n.langCode == 'ar';

    final preview = _PreviewPane(
      key: ValueKey(
        '${_style.hashCode}-${_paper.name}-${l10n.langCode}-$_previewRefreshKey',
      ),
      buildPdf: () => _buildPreview(l10n),
      paper: _paper,
      isRtl: isArabic,
      stamp: _stampConfig,
      signature: _sigConfig,
      stampBytes: _stampBytes,
      signatureBytes: _sigBytes,
      onStampChanged: (c) => setState(() => _stampConfig = c),
      onSignatureChanged: (c) => setState(() => _sigConfig = c),
      onInteractionEnd: () {
        if (_stampConfig != null) {
          DatabaseHelper.instance.saveBusinessSealConfig(
            _businessId,
            _stampConfig!,
          );
        }
        if (_sigConfig != null) {
          DatabaseHelper.instance.saveBusinessSealConfig(
            _businessId,
            _sigConfig!,
          );
        }
        setState(() => _previewRefreshKey++);
      },
    );

    final options = _OptionsList(
      l10n: l10n,
      style: _style,
      paper: _paper,
      footerCtrl: _footerCtrl,
      stampConfig: _stampConfig,
      sigConfig: _sigConfig,
      stampBytes: _stampBytes,
      sigBytes: _sigBytes,
      isPro: isPro,
      onUpgradeRequested: _handleProUpgrade,
      onChanged: _update,
      onPaperChanged: _setPaper,
      onFooterChanged: (text) {
        _footerDebounce?.cancel();
        _footerDebounce = Timer(
          const Duration(milliseconds: 500),
          () => _update(_style.copyWith(footerText: text)),
        );
      },
      onPickSeal: _pickSeal,
      onRemoveSeal: _removeSeal,
      onUpdateSealConfig: _updateSealConfig,
      onResetSealPosition: _resetSealPosition,
    );

    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pdfCustomize),
        actions: [
          IconButton(
            tooltip: l10n.pdfResetDefaults,
            icon: const Icon(Icons.restart_alt),
            onPressed: () async {
              final ok = await AppConfirmDialog.show(
                context,
                title: l10n.pdfResetConfirmTitle,
                message: l10n.pdfResetConfirmMessage,
                confirmLabel: l10n.pdfResetDefaults,
                isDestructive: true,
              );
              if (ok && mounted) await _reset();
            },
          ),
        ],
      ),
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 440, child: options),
                const VerticalDivider(width: 1),
                Expanded(child: preview),
              ],
            )
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(icon: const Icon(Icons.tune), text: l10n.pdfOptions),
                      Tab(
                        icon: const Icon(Icons.visibility_outlined),
                        text: l10n.pdfPreview,
                      ),
                    ],
                  ),
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
  final PaperSize paper;
  final bool isRtl;
  final DigitalSealConfig? stamp;
  final DigitalSealConfig? signature;
  final Uint8List? stampBytes;
  final Uint8List? signatureBytes;
  final ValueChanged<DigitalSealConfig>? onStampChanged;
  final ValueChanged<DigitalSealConfig>? onSignatureChanged;
  final VoidCallback? onInteractionEnd;

  const _PreviewPane({
    super.key,
    required this.buildPdf,
    required this.paper,
    required this.isRtl,
    this.stamp,
    this.signature,
    this.stampBytes,
    this.signatureBytes,
    this.onStampChanged,
    this.onSignatureChanged,
    this.onInteractionEnd,
  });

  @override
  Widget build(BuildContext context) {
    final pdfPreview = PdfPreview(
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

    final isPro = FeatureGate.isAvailable(Feature.digitalSeals);
    final hasActiveSeals =
        isPro &&
        ((stamp != null && stamp!.isEnabled && stampBytes != null) ||
            (signature != null && signature!.isEnabled && signatureBytes != null));

    if (paper == PaperSize.thermal80mm || !hasActiveSeals) {
      return pdfPreview;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final format = PrintSettings.pageFormatFor(paper);
        final aspect = format.width / format.height;

        double previewWidth = constraints.maxWidth - 32;
        double previewHeight = constraints.maxHeight - 32;

        double pageWidth = previewWidth;
        double pageHeight = pageWidth / aspect;
        if (pageHeight > previewHeight) {
          pageHeight = previewHeight;
          pageWidth = pageHeight * aspect;
        }

        final margin = paper == PaperSize.a5 ? 16.0 : 24.0;
        final marginScale = pageWidth / format.width;
        final printableWidth = pageWidth - (margin * 2 * marginScale);
        final printableHeight = pageHeight - (margin * 2 * marginScale);

        return Stack(
          alignment: Alignment.center,
          children: [
            pdfPreview,
            SizedBox(
              width: printableWidth,
              height: printableHeight,
              child: SealEditorOverlay(
                containerWidth: printableWidth,
                containerHeight: printableHeight,
                isRtl: isRtl,
                stamp: stamp,
                signature: signature,
                stampBytes: stampBytes,
                signatureBytes: signatureBytes,
                onStampChanged: onStampChanged,
                onSignatureChanged: onSignatureChanged,
                onInteractionEnd: onInteractionEnd,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OptionsList extends StatelessWidget {
  final AppLocalizations l10n;
  final PdfStyleSettings style;
  final PaperSize paper;
  final TextEditingController footerCtrl;
  final DigitalSealConfig? stampConfig;
  final DigitalSealConfig? sigConfig;
  final Uint8List? stampBytes;
  final Uint8List? sigBytes;
  final bool isPro;
  final VoidCallback onUpgradeRequested;
  final ValueChanged<PdfStyleSettings> onChanged;
  final ValueChanged<PaperSize> onPaperChanged;
  final ValueChanged<String> onFooterChanged;
  final void Function(SealType) onPickSeal;
  final void Function(SealType) onRemoveSeal;
  final void Function(DigitalSealConfig) onUpdateSealConfig;
  final void Function(SealType) onResetSealPosition;

  const _OptionsList({
    required this.l10n,
    required this.style,
    required this.paper,
    required this.footerCtrl,
    required this.stampConfig,
    required this.sigConfig,
    required this.stampBytes,
    required this.sigBytes,
    required this.isPro,
    required this.onUpgradeRequested,
    required this.onChanged,
    required this.onPaperChanged,
    required this.onFooterChanged,
    required this.onPickSeal,
    required this.onRemoveSeal,
    required this.onUpdateSealConfig,
    required this.onResetSealPosition,
  });

  Widget _buildSealCard({
    required BuildContext context,
    required String title,
    required SealType type,
    required DigitalSealConfig? config,
    required Uint8List? bytes,
  }) {
    final cs = Theme.of(context).colorScheme;
    final hasImage = bytes != null && bytes.isNotEmpty;
    final isEnabled = config?.isEnabled ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  type == SealType.stamp ? Icons.approval : Icons.draw,
                  color: cs.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (!isPro) ...[
                            const SizedBox(width: 8),
                            const ProBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        type == SealType.stamp
                            ? l10n.pdfDigitalStampDesc
                            : l10n.pdfDigitalSignatureDesc,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isPro)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onUpgradeRequested,
                    child: const IgnorePointer(
                      child: Switch(
                        value: false,
                        onChanged: null,
                      ),
                    ),
                  )
                else
                  Switch(
                    value: isEnabled && hasImage,
                    onChanged: hasImage
                        ? (v) =>
                              onUpdateSealConfig(config!.copyWith(isEnabled: v))
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (hasImage) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                      color: cs.surfaceContainerHighest,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Opacity(
                      opacity: config!.opacity.clamp(0.1, 1.0),
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.sync, size: 16),
                              label: Text(l10n.pdfReplaceSeal),
                              onPressed: isPro
                                  ? () => onPickSeal(type)
                                  : onUpgradeRequested,
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: Text(l10n.pdfRemoveSeal),
                              style: TextButton.styleFrom(
                                foregroundColor: cs.error,
                              ),
                              onPressed: isPro
                                  ? () => onRemoveSeal(type)
                                  : null,
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: isPro
                              ? () => onResetSealPosition(type)
                              : null,
                          child: Text(
                            l10n.pdfSealResetPosition,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${l10n.pdfSealOpacity}: ${(config.opacity * 100).toInt()}%',
                style: const TextStyle(fontSize: 12),
              ),
              Slider(
                value: config.opacity.clamp(0.1, 1.0),
                min: 0.1,
                max: 1.0,
                divisions: 9,
                onChanged: isPro
                    ? (v) =>
                          onUpdateSealConfig(config.copyWith(opacity: v))
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.pdfSealPagePlacement,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              SegmentedButton<SealPageRule>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: SealPageRule.lastPage,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l10n.pdfSealPageLast,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                  ButtonSegment(
                    value: SealPageRule.firstPage,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l10n.pdfSealPageFirst,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                  ButtonSegment(
                    value: SealPageRule.allPages,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l10n.pdfSealPageAll,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ],
                selected: {config.pageRule},
                onSelectionChanged: isPro
                    ? (s) =>
                          onUpdateSealConfig(config.copyWith(pageRule: s.first))
                    : null,
              ),
            ] else ...[
              Center(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: Text(l10n.pdfUploadSeal),
                  onPressed: isPro
                      ? () => onPickSeal(type)
                      : onUpgradeRequested,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget section(String title) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: cs.primary,
          fontSize: 13,
        ),
      ),
    );

    Widget segmented<T>(
      List<(T, String, IconData?)> values,
      T selected,
      ValueChanged<T> onSelect,
    ) => Padding(
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

    Widget toggle(
      String title,
      bool value,
      PdfStyleSettings Function(bool) f,
    ) => SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: (v) => onChanged(f(v)),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        section(l10n.pdfTemplate),
        segmented<PdfTemplate>(
          [
            (
              PdfTemplate.classic,
              l10n.pdfTemplateClassic,
              Icons.article_outlined,
            ),
            (
              PdfTemplate.modern,
              l10n.pdfTemplateModern,
              Icons.dashboard_outlined,
            ),
            (PdfTemplate.minimal, l10n.pdfTemplateMinimal, Icons.notes),
          ],
          style.template,
          (v) => onChanged(style.copyWith(template: v)),
        ),

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
        segmented<PaperSize>(
          [
            for (final s in PaperSize.values)
              (s, PrintSettings.labelFor(s, l10n), null),
          ],
          paper,
          onPaperChanged,
        ),

        section(l10n.pdfLogo),
        segmented<PdfLogoShape>(
          [
            (PdfLogoShape.circle, l10n.pdfLogoCircle, Icons.circle_outlined),
            (PdfLogoShape.rounded, l10n.pdfLogoRounded, Icons.crop_square),
            (
              PdfLogoShape.hidden,
              l10n.pdfLogoHidden,
              Icons.visibility_off_outlined,
            ),
          ],
          style.logoShape,
          (v) => onChanged(style.copyWith(logoShape: v)),
        ),

        section(l10n.pdfTextSize),
        segmented<double>(
          [
            (0.9, l10n.pdfTextSmall, null),
            (1.0, l10n.pdfTextNormal, null),
            (1.12, l10n.pdfTextLarge, null),
          ],
          PdfStyleSettings.fontScales.contains(style.fontScale)
              ? style.fontScale
              : 1.0,
          (v) => onChanged(style.copyWith(fontScale: v)),
        ),

        // Digital Stamp & Signature Section
        section(l10n.pdfDigitalSealsHeader),
        _buildSealCard(
          context: context,
          title: l10n.pdfSealStamp,
          type: SealType.stamp,
          config: stampConfig,
          bytes: stampBytes,
        ),
        _buildSealCard(
          context: context,
          title: l10n.pdfSealSignature,
          type: SealType.signature,
          config: sigConfig,
          bytes: sigBytes,
        ),

        // Paper Placeholders Section
        section(l10n.pdfPaperStampSignatureSection),
        SwitchListTile(
          title: Text(l10n.pdfShowSignatureLine),
          subtitle: Text(
            l10n.pdfShowSignatureLineDesc,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          value: style.showSignature,
          onChanged: (v) => onChanged(style.copyWith(showSignature: v)),
        ),
        SwitchListTile(
          title: Text(l10n.pdfShowStampBox),
          subtitle: Text(
            l10n.pdfShowStampBoxDesc,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          value: style.effectiveShowStampBox,
          onChanged: (v) => onChanged(style.copyWith(showPrintedStamp: v)),
        ),
        if ((stampConfig?.isEnabled == true && stampBytes != null) &&
            style.effectiveShowStampBox) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.pdfStampNoticeBoth,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        section(l10n.pdfFields),
        toggle(
          l10n.pdfShowBusinessContact,
          style.showBusinessContact,
          (v) => style.copyWith(showBusinessContact: v),
        ),
        toggle(
          l10n.pdfShowTaxId,
          style.showTaxId,
          (v) => style.copyWith(showTaxId: v),
        ),
        toggle(
          l10n.pdfShowCustomer,
          style.showCustomer,
          (v) => style.copyWith(showCustomer: v),
        ),
        toggle(
          l10n.pdfShowNotes,
          style.showNotes,
          (v) => style.copyWith(showNotes: v),
        ),
        toggle(
          l10n.pdfShowPaymentSummary,
          style.showPaymentSummary,
          (v) => style.copyWith(showPaymentSummary: v),
        ),
        toggle(
          l10n.pdfZebraRows,
          style.zebraRows,
          (v) => style.copyWith(zebraRows: v),
        ),
        toggle(
          l10n.pdfShowPageNumbers,
          style.showPageNumbers,
          (v) => style.copyWith(showPageNumbers: v),
        ),

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
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: AppLocalizations.of(context).pdfAccentColor,
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
              ? Icon(
                  Icons.check,
                  color: ThemeData.estimateBrightnessForColor(color) ==
                          Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                  size: 20,
                )
              : null,
        ),
      ),
    );
  }
}
