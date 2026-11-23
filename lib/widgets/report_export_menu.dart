import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../services/access/access_guard.dart';
import '../services/access/permission_registry.dart';

enum ReportExportAction { printPdf, sharePdf, shareWhatsApp, exportCsv }

class ReportExportPermissions {
  /// Pure function resolving visible export actions based on available callbacks and permissions.
  static Set<ReportExportAction> resolveVisibleActions({
    required bool hasPdfPermission,
    required bool hasCsvPermission,
    bool hasPrintPdf = true,
    bool hasSharePdf = false,
    bool hasShareWhatsApp = false,
    bool hasExportCsv = false,
  }) {
    final actions = <ReportExportAction>{};
    if (hasPdfPermission) {
      if (hasPrintPdf) actions.add(ReportExportAction.printPdf);
      if (hasSharePdf) actions.add(ReportExportAction.sharePdf);
      if (hasShareWhatsApp) actions.add(ReportExportAction.shareWhatsApp);
    }
    if (hasCsvPermission) {
      if (hasExportCsv) actions.add(ReportExportAction.exportCsv);
    }
    return actions;
  }
}

/// Modal bottom sheet presenting uniform export and sharing options across reports:
/// - Print / PDF preview (requires reports.export_pdf)
/// - Share PDF file (requires reports.export_pdf)
/// - Share text summary (requires reports.export_pdf)
/// - Export table as CSV spreadsheet (requires data.export_csv)
class ReportExportMenu {
  /// Checks whether the current user has permission to perform any export action.
  static bool canExport({bool hasPdf = true, bool hasCsv = true}) {
    final canPdf =
        hasPdf && AccessGuard.can(PermissionRegistry.reportsExportPdf);
    final canCsv = hasCsv && AccessGuard.can(PermissionRegistry.dataExportCsv);
    return canPdf || canCsv;
  }

  static Future<void> show({
    required BuildContext context,
    required String title,
    required Future<void> Function() onPrintPdf,
    Future<void> Function()? onSharePdf,
    Future<void> Function()? onShareWhatsApp,
    Future<void> Function()? onExportCsv,
  }) async {
    final hasPdfPerm = AccessGuard.can(PermissionRegistry.reportsExportPdf);
    final hasCsvPerm = AccessGuard.can(PermissionRegistry.dataExportCsv);

    final visibleActions = ReportExportPermissions.resolveVisibleActions(
      hasPdfPermission: hasPdfPerm,
      hasCsvPermission: hasCsvPerm,
      hasPrintPdf: true,
      hasSharePdf: onSharePdf != null,
      hasShareWhatsApp: onShareWhatsApp != null,
      hasExportCsv: onExportCsv != null,
    );

    if (visibleActions.isEmpty) return;

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
              if (visibleActions.contains(ReportExportAction.printPdf))
                ListTile(
                  leading: Icon(Icons.print_outlined, color: cs.primary),
                  title: Text(l10n.printOrPreviewPdf),
                  onTap: () {
                    Navigator.pop(ctx);
                    onPrintPdf();
                  },
                ),
              if (visibleActions.contains(ReportExportAction.sharePdf))
                ListTile(
                  leading: Icon(
                    Icons.picture_as_pdf_outlined,
                    color: cs.primary,
                  ),
                  title: Text(l10n.sharePdfFile),
                  onTap: () {
                    Navigator.pop(ctx);
                    onSharePdf!();
                  },
                ),
              if (visibleActions.contains(ReportExportAction.shareWhatsApp))
                ListTile(
                  leading: const Icon(
                    Icons.chat_outlined,
                    color: Color(0xFF25D366),
                  ),
                  title: Text(l10n.shareWhatsAppSummary),
                  onTap: () {
                    Navigator.pop(ctx);
                    onShareWhatsApp!();
                  },
                ),
              if (visibleActions.contains(ReportExportAction.exportCsv))
                ListTile(
                  leading: Icon(
                    Icons.table_chart_outlined,
                    color: cs.secondary,
                  ),
                  title: Text(l10n.exportCsvTable),
                  onTap: () {
                    Navigator.pop(ctx);
                    onExportCsv!();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
