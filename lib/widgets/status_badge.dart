import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../models/document_status.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, color) = _resolve(status, l10n);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }

  static (String, Color) _resolve(String status, AppLocalizations l10n) {
    return switch (status) {
      DocumentStatus.draft         => (l10n.statusDraft,         const Color(0xFF6B7280)),
      DocumentStatus.issued        => (l10n.statusIssued,        const Color(0xFF2563EB)),
      DocumentStatus.partiallyPaid => (l10n.statusPartiallyPaid, const Color(0xFFD97706)),
      DocumentStatus.paid          => (l10n.statusPaid,          const Color(0xFF16A34A)),
      DocumentStatus.cancelled     => (l10n.statusCancelled,     const Color(0xFFDC2626)),
      _                            => (l10n.statusIssued,        const Color(0xFF2563EB)),
    };
  }
}
