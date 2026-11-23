import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';

/// Modal bottom sheet presenting uniform export and sharing options across reports:
/// - Print / PDF preview
/// - Share PDF file
/// - Share text summary (WhatsApp friendly)
/// - Export table as CSV spreadsheet
class ReportExportMenu {
  static Future<void> show({
    required BuildContext context,
    required String title,
    required Future<void> Function() onPrintPdf,
    Future<void> Function()? onSharePdf,
    Future<void> Function()? onShareWhatsApp,
    Future<void> Function()? onExportCsv,
  }) async {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(Icons.ios_share, size: 20, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.exportOptions,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.print_outlined, color: cs.primary),
                title: Text(l10n.printOrPreviewPdf),
                onTap: () {
                  Navigator.pop(ctx);
                  onPrintPdf();
                },
              ),
              if (onSharePdf != null)
                ListTile(
                  leading: Icon(
                    Icons.picture_as_pdf_outlined,
                    color: cs.primary,
                  ),
                  title: Text(l10n.sharePdfFile),
                  onTap: () {
                    Navigator.pop(ctx);
                    onSharePdf();
                  },
                ),
              if (onShareWhatsApp != null)
                ListTile(
                  leading: const Icon(
                    Icons.chat_outlined,
                    color: Color(0xFF25D366),
                  ),
                  title: Text(l10n.shareWhatsAppSummary),
                  onTap: () {
                    Navigator.pop(ctx);
                    onShareWhatsApp();
                  },
                ),
              if (onExportCsv != null)
                ListTile(
                  leading: Icon(
                    Icons.table_chart_outlined,
                    color: cs.secondary,
                  ),
                  title: Text(l10n.exportCsvTable),
                  onTap: () {
                    Navigator.pop(ctx);
                    onExportCsv();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
