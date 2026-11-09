import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../utils/date_format_utils.dart';
import '../widgets/access/sensitive_action_gate.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_date_picker.dart';
import '../widgets/app_design_tokens.dart';
import '../widgets/app_loading_view.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/responsive.dart';

/// Screen dedicated to managing the accounting period lock (books closed through date).
///
/// Prevents creating, editing, or deleting transactions on or before the closing date.
class PeriodClosingScreen extends StatefulWidget {
  const PeriodClosingScreen({super.key});

  @override
  State<PeriodClosingScreen> createState() => _PeriodClosingScreenState();
}

class _PeriodClosingScreenState extends State<PeriodClosingScreen> {
  bool _loading = true;
  DateTime? _booksClosedThrough;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final closedThrough = await DatabaseHelper.instance.getBooksClosedThrough();
    if (!mounted) return;
    setState(() {
      _booksClosedThrough = closedThrough;
      _loading = false;
    });
  }

  Future<void> _pickLockDate() async {
    final l10n = AppLocalizations.of(context);
    final initialDate = _booksClosedThrough ?? DateTime.now();
    final picked = await AppDatePicker.show(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;

    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.confirmSetPeriodLockTitle,
      message: l10n.confirmSetPeriodLockMessage,
      confirmLabel: l10n.confirm,
      isDestructive: false,
    );
    if (!confirmed || !mounted) return;

    final authed = await SensitiveActionGate.reauthenticate(
      context,
      title: l10n.confirmSetPeriodLockTitle,
      message: l10n.confirmSetPeriodLockMessage,
    );
    if (!authed || !mounted) return;

    await DatabaseHelper.instance.setBooksClosedThrough(picked);
    await _load();
    if (!mounted) return;
    AppSnackBar.show(
      context,
      '${l10n.periodLockClosedThrough}: ${AppDateUtils.formatDate(picked)}',
      severity: AppSnackBarSeverity.success,
    );
  }

  Future<void> _clearLockDate() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.confirmClearPeriodLockTitle,
      message: l10n.confirmClearPeriodLockMessage,
      confirmLabel: l10n.confirm,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final authed = await SensitiveActionGate.reauthenticate(
      context,
      title: l10n.confirmClearPeriodLockTitle,
      message: l10n.confirmClearPeriodLockMessage,
    );
    if (!authed || !mounted) return;

    await DatabaseHelper.instance.setBooksClosedThrough(null);
    await _load();
    if (!mounted) return;
    AppSnackBar.show(
      context,
      l10n.periodLockOpen,
      severity: AppSnackBarSeverity.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isClosed = _booksClosedThrough != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.periodLockSection),
      ),
      body: _loading
          ? const AppLoadingView()
          : ResponsiveCenter(
              maxWidth: 600,
              child: ListView(
                padding: const EdgeInsets.all(AppDesignTokens.space16),
                children: [
                  // Status card
                  Container(
                    padding: const EdgeInsets.all(AppDesignTokens.space20),
                    decoration: BoxDecoration(
                      color: isClosed
                          ? Colors.orange.withValues(alpha: 0.08)
                          : Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
                      border: Border.all(
                        color: isClosed
                            ? Colors.orange.withValues(alpha: 0.4)
                            : Colors.green.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (isClosed ? Colors.orange : Colors.green)
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isClosed
                                    ? Icons.lock_outline_rounded
                                    : Icons.lock_open_rounded,
                                color: isClosed ? Colors.orange : Colors.green,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isClosed
                                        ? '${l10n.periodLockClosedThrough}: ${AppDateUtils.formatDate(_booksClosedThrough)}'
                                        : l10n.periodLockOpen,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isClosed
                                          ? (theme.brightness == Brightness.dark
                                              ? Colors.orangeAccent
                                              : Colors.deepOrange.shade800)
                                          : (theme.brightness == Brightness.dark
                                              ? Colors.greenAccent
                                              : Colors.green.shade800),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.periodLockSectionDesc,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Actions
                  FilledButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(l10n.setPeriodLock),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: _pickLockDate,
                  ),

                  if (isClosed) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.lock_open_rounded),
                      label: Text(l10n.clearPeriodLock),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        foregroundColor: theme.colorScheme.error,
                      ),
                      onPressed: _clearLockDate,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
