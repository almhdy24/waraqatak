import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_localizations.dart';
import '../screens/about_screen.dart';
import '../utils/support_diagnostics.dart';
import 'app_snackbar.dart';

/// Standard, Play-compliant support guidance card.
///
/// Directs users to the central About page for official support channels and
/// provides an effortless button to copy masked diagnostic details.
class SupportGuidanceCard extends StatelessWidget {
  final String? referenceId;
  final String? rawKey;
  final bool compact;

  const SupportGuidanceCard({
    super.key,
    this.referenceId,
    this.rawKey,
    this.compact = false,
  });

  Future<void> _copyDiagnostics(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final summary = await SupportDiagnostics.generateSummary(
      referenceId: referenceId,
      rawKey: rawKey,
    );
    await Clipboard.setData(ClipboardData(text: summary));
    if (context.mounted) {
      AppSnackBar.show(context, l10n.supportInfoCopied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.help_outline_rounded,
                  size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.supportFromAboutPage,
                  style: TextStyle(
                    fontSize: compact ? 12.5 : 13.5,
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          if (referenceId != null && referenceId!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.referenceIdLabel(referenceId!.trim()),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: referenceId!.trim()));
                      AppSnackBar.show(context, l10n.copiedToClipboard);
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _copyDiagnostics(context),
                icon: const Icon(Icons.copy_all_rounded, size: 16),
                label: Text(l10n.copySupportInfo, style: const TextStyle(fontSize: 12.5)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
                icon: const Icon(Icons.info_outline, size: 16),
                label: Text(l10n.openAboutPage, style: const TextStyle(fontSize: 12.5)),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
