import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../localization/app_localizations.dart';
import '../services/csv_service.dart';
import '../services/feature_access.dart';
import '../services/license_service.dart';
import '../utils/error_utils.dart';
import '../widgets/pro_upgrade_sheet.dart';
import '../widgets/responsive.dart';

class CsvImportExportScreen extends StatefulWidget {
  const CsvImportExportScreen({super.key});

  @override
  State<CsvImportExportScreen> createState() => _CsvImportExportScreenState();
}

class _CsvImportExportScreenState extends State<CsvImportExportScreen> {
  bool _loading = false;
  CsvImportPreview? _preview;
  CsvDuplicateStrategy _strategy = CsvDuplicateStrategy.skip;
  CsvImportResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _checkEntitlement();
  }

  Future<void> _checkEntitlement() async {
    final entitlement =
        await LicenseService.instance.checkEntitlement(force: true);
    if (!mounted) return;
    if (!FeatureAccess.canAccess(Feature.csvImportExport, entitlement)) {
      if (mounted) {
        await ProUpgradeSheet.show(context, feature: Feature.csvImportExport);
        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  Future<void> _exportProducts({bool templateOnly = false}) async {
    setState(() => _loading = true);
    try {
      final bytes = await CsvService.instance.exportProducts(templateOnly: templateOnly);
      final filename = templateOnly
          ? 'waraqatak_products_template.csv'
          : 'waraqatak_products_${DateTime.now().millisecondsSinceEpoch}.csv';

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'text/csv')],
          fileNameOverrides: [filename],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e, l10n: AppLocalizations.of(context)))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndPreviewCsv() async {
    setState(() => _loading = true);
    try {
      final file = await FilePicker.pickFile(
        type: FileType.any,
      );

      if (file == null) {
        setState(() => _loading = false);
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('الملف المحدد فارغ');
      }

      final preview = await CsvService.instance.previewImport(bytes);
      setState(() {
        _preview = preview;
        _lastResult = null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e, l10n: AppLocalizations.of(context)))),
        );
      }
    }
  }

  Future<void> _confirmAndImport() async {
    if (_preview == null || !_preview!.canImport) return;
    final l10n = AppLocalizations.of(context);

    setState(() => _loading = true);
    try {
      final result = await CsvService.instance.applyImport(
        rows: _preview!.rows,
        strategy: _strategy,
      );
      setState(() {
        _lastResult = result;
        _preview = null;
        _loading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.importedCount}: ${result.importedCount} • ${l10n.updatedCount}: ${result.updatedCount}',
          ),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e, l10n: l10n))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.csvImportExportTitle),
      ),
      body: ResponsiveCenter(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Export Section
                    Card(
                      elevation: 0,
                      color: cs.surfaceContainerLow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.file_upload_outlined, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.exportProductsCsv,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _exportProducts(templateOnly: false),
                                    icon: const Icon(Icons.download_rounded),
                                    label: Text(l10n.exportProductsCsv),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _exportProducts(templateOnly: true),
                                  icon: const Icon(Icons.description_outlined),
                                  label: Text(l10n.downloadTemplate),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Import Section
                    Card(
                      elevation: 0,
                      color: cs.surfaceContainerLow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.file_download_outlined, color: Colors.teal),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.importProductsCsv,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Stock safeguard notice
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      l10n.csvStockInfoNotice,
                                      style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            FilledButton.tonalIcon(
                              onPressed: _pickAndPreviewCsv,
                              icon: const Icon(Icons.attach_file),
                              label: Text(l10n.selectCsvFile),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Preview Section
                    if (_preview != null) ...[
                      const SizedBox(height: 16),
                      Card(
                        elevation: 0,
                        color: cs.surfaceContainerLow,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.previewImport,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _statChip(l10n.validRows, '${_preview!.validNewCount}', color: Colors.teal),
                                  _statChip(l10n.duplicateHandling, '${_preview!.existingCount}', color: Colors.blue),
                                  _statChip(l10n.invalidRows, '${_preview!.errorCount}', color: Colors.red),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Duplicate strategy dropdown
                              DropdownButtonFormField<CsvDuplicateStrategy>(
                                decoration: InputDecoration(
                                  labelText: l10n.duplicateHandling,
                                  isDense: true,
                                ),
                                initialValue: _strategy,
                                items: [
                                  DropdownMenuItem(
                                    value: CsvDuplicateStrategy.skip,
                                    child: Text(l10n.skipDuplicates),
                                  ),
                                  DropdownMenuItem(
                                    value: CsvDuplicateStrategy.update,
                                    child: Text(l10n.updateExisting),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _strategy = val);
                                },
                              ),

                              const SizedBox(height: 16),

                              // Preview rows list (first 10)
                              SizedBox(
                                height: 200,
                                child: ListView.separated(
                                  itemCount: _preview!.rows.length.clamp(0, 50),
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (ctx, idx) {
                                    final r = _preview!.rows[idx];
                                    return ListTile(
                                      dense: true,
                                      title: Text(
                                        r.name.isEmpty ? '(صف غير صالح)' : r.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: r.isValid ? cs.onSurface : Colors.red,
                                        ),
                                      ),
                                      subtitle: Text(
                                        r.errorMessage ??
                                            'سعر: ${r.salePrice} ${r.isExisting ? "• منتج موجود" : "• منتج جديد"}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: r.isValid ? Colors.grey : Colors.red,
                                        ),
                                      ),
                                      trailing: Icon(
                                        r.isValid ? Icons.check_circle : Icons.error,
                                        color: r.isValid ? (r.isExisting ? Colors.blue : Colors.teal) : Colors.red,
                                        size: 16,
                                      ),
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 16),

                              FilledButton.icon(
                                onPressed: _preview!.canImport ? _confirmAndImport : null,
                                icon: const Icon(Icons.check),
                                label: Text(l10n.confirmImport),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Completion Summary
                    if (_lastResult != null) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: Colors.teal.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.teal),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.importSummary,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.teal.shade900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('${l10n.importedCount}: ${_lastResult!.importedCount}'),
                              Text('${l10n.updatedCount}: ${_lastResult!.updatedCount}'),
                              Text('${l10n.skippedCount}: ${_lastResult!.skippedCount}'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _statChip(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
