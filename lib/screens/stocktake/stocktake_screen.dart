import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/stocktake.dart';
import '../../services/feature_access.dart';
import '../../services/license_service.dart';
import '../../services/stocktake_service.dart';
import '../../utils/format_utils.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/pro_upgrade_sheet.dart';
import '../../widgets/responsive.dart';
import 'stocktake_history_screen.dart';

class StocktakeScreen extends StatefulWidget {
  final int? existingSessionId;

  const StocktakeScreen({super.key, this.existingSessionId});

  @override
  State<StocktakeScreen> createState() => _StocktakeScreenState();
}

class _StocktakeScreenState extends State<StocktakeScreen> {
  StocktakeSession? _session;
  List<StocktakeItem> _items = [];
  List<String> _categories = [];
  String? _selectedCategory;
  String _searchQuery = '';
  String _filterTab = 'all'; // all, uncounted, counted, discrepant
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkEntitlementAndLoad();
  }

  Future<void> _checkEntitlementAndLoad() async {
    final entitlement =
        await LicenseService.instance.checkEntitlement(force: true);
    if (!mounted) return;
    if (!FeatureAccess.canAccess(Feature.stocktake, entitlement)) {
      if (mounted) {
        await ProUpgradeSheet.show(context, feature: Feature.stocktake);
        if (mounted) Navigator.of(context).pop();
      }
      return;
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      final catRows = await db.rawQuery(
        "SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND category != '' ORDER BY category ASC",
      );
      _categories = catRows.map((r) => r['category'] as String).toList();

      if (widget.existingSessionId != null) {
        _session = await StocktakeService.instance.getSession(widget.existingSessionId!);
      } else {
        // Look for any active in-progress session
        final sessions = await StocktakeService.instance.getAllSessions(limit: 5);
        final active = sessions.where((s) => s.isActive).toList();
        if (active.isNotEmpty) {
          _session = active.first;
        }
      }

      if (_session != null) {
        _items = await StocktakeService.instance.getItems(_session!.id!);
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _startNewSession() async {
    final l10n = AppLocalizations.of(context);
    String? categoryFilter;
    final notesController = TextEditingController();

    final started = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.startStocktake),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_categories.isNotEmpty)
                DropdownButtonFormField<String?>(
                  decoration: InputDecoration(
                    labelText: l10n.category,
                    prefixIcon: const Icon(Icons.category_outlined),
                  ),
                  initialValue: categoryFilter,
                  items: [
                    DropdownMenuItem(value: null, child: Text(l10n.allCategories)),
                    ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                  ],
                  onChanged: (val) => setDialogState(() => categoryFilter = val),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: l10n.notes,
                  prefixIcon: const Icon(Icons.notes_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.startStocktake),
            ),
          ],
        ),
      ),
    );

    if (started == true) {
      setState(() => _loading = true);
      try {
        final session = await StocktakeService.instance.startSession(
          categoryFilter: categoryFilter,
          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        );
        setState(() {
          _session = session;
        });
        await _load();
      } catch (e) {
        if (!mounted) return;
        AppSnackBar.show(
          context,
          e.toString(),
          severity: AppSnackBarSeverity.error,
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _editItemCount(StocktakeItem item) async {
    if (_session?.isCompleted == true || _session?.isCancelled == true) return;
    final l10n = AppLocalizations.of(context);
    final countController = TextEditingController(
      text: item.countedQuantity != null ? FormatUtils.formatQuantity(item.countedQuantity!) : '',
    );
    final notesController = TextEditingController(text: item.notes ?? '');

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.productName ?? l10n.product),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.systemQty}: ${FormatUtils.formatQuantity(item.baselineQuantity)} ${item.productUnit ?? ""}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: countController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.countedQty,
                hintText: '0.0',
                suffixText: item.productUnit ?? '',
                prefixIcon: const Icon(Icons.pin_outlined),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: l10n.notes,
                prefixIcon: const Icon(Icons.notes_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Clear count (uncount)
              await StocktakeService.instance.recordCount(item.id!, null);
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: Text(l10n.uncounted, style: const TextStyle(color: Colors.red)),
          ),
          FilledButton(
            onPressed: () {
              final text = countController.text.trim();
              final qty = double.tryParse(text);
              if (text.isNotEmpty && (qty == null || qty < 0)) {
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (updated == true) {
      final text = countController.text.trim();
      final qty = text.isEmpty ? null : double.tryParse(text);
      await StocktakeService.instance.recordCount(
        item.id!,
        qty,
        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
      );
      await _load();
    }
  }

  Future<void> _reviewAndFinalize() async {
    if (_session == null) return;
    final l10n = AppLocalizations.of(context);

    setState(() => _loading = true);
    try {
      final review = await StocktakeService.instance.reviewSession(_session!.id!);
      setState(() => _loading = false);
      if (!mounted) return;

      bool confirmed = false;

      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(l10n.reviewAndFinalize),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.sessionNumber}: ${_session!.sessionNumber}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    _summaryRow(l10n.total, '${_items.length}'),
                    _summaryRow(l10n.countedQty, '${review.totalCounted}'),
                    _summaryRow(l10n.uncounted, '${review.totalUncounted}', color: Colors.orange),
                    _summaryRow(l10n.statusMatched, '${review.matchedCount}', color: Colors.teal),
                    _summaryRow(l10n.variance, '${review.discrepantCount}',
                        color: review.discrepantCount > 0 ? Colors.red : Colors.teal),
                    const Divider(height: 16),
                    if (review.hasInterimMovements) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.interimMovementWarning,
                                style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.stocktakeDiscrepancyWarning,
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: confirmed,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l10n.confirmFinalizeStocktake,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onChanged: (val) => setDialogState(() => confirmed = val ?? false),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: confirmed
                    ? () => Navigator.pop(ctx, true)
                    : null,
                child: Text(l10n.confirmFinalizeStocktake),
              ),
            ],
          ),
        ),
      );

      if (result == true) {
        setState(() => _loading = true);
        await StocktakeService.instance.finalizeSession(
          _session!.id!,
          confirmed: true,
        );
        if (!mounted) return;
        AppSnackBar.show(
          context,
          l10n.stocktakeFinalizedSuccess,
          severity: AppSnackBarSeverity.success,
        );
        await _load();
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        e.toString(),
        severity: AppSnackBarSeverity.error,
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _cancelSession() async {
    if (_session == null || _session!.isCompleted) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancelStocktakeSession),
        content: Text(l10n.confirmCancelSession),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.cancelStocktakeSession),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _loading = true);
      await StocktakeService.instance.cancelSession(_session!.id!);
      await _load();
    }
  }

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.stocktakeTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.stocktakeTitle)),
        body: Center(child: Text(_error!)),
      );
    }

    if (_session == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.stocktakeTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: l10n.auditHistoryTitle,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StocktakeHistoryScreen()),
              ),
            ),
          ],
        ),
        body: ResponsiveCenter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fact_check_outlined, size: 64, color: cs.primary),
                  const SizedBox(height: 16),
                  Text(
                    l10n.stocktakeTitle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.noStocktakeSessions,
                    style: TextStyle(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _startNewSession,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.startStocktake),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Filter items
    final filtered = _items.where((it) {
      if (_selectedCategory != null && it.productCategory != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = it.productName?.toLowerCase().contains(q) ?? false;
        final matchBarcode = it.productBarcode?.toLowerCase().contains(q) ?? false;
        final matchCode = it.productCode?.toLowerCase().contains(q) ?? false;
        if (!matchName && !matchBarcode && !matchCode) return false;
      }
      if (_filterTab == 'uncounted' && it.isCounted) return false;
      if (_filterTab == 'counted' && !it.isCounted) return false;
      if (_filterTab == 'discrepant' && (!it.isCounted || it.currentVariance.abs() < 0.0001)) {
        return false;
      }
      return true;
    }).toList();

    final countedCount = _items.where((i) => i.isCounted).length;
    final discrepantCount = _items.where((i) => i.isCounted && i.currentVariance.abs() > 0.0001).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.stocktakeTitle, style: const TextStyle(fontSize: 16)),
            Text(
              '${_session!.sessionNumber} (${_items.length} ${l10n.product})',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: l10n.auditHistoryTitle,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StocktakeHistoryScreen()),
            ),
          ),
          if (_session!.isActive)
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'cancel') _cancelSession();
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.cancelStocktakeSession, style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            // Status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: cs.surfaceContainerLow,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statChip(l10n.total, '${_items.length}'),
                  _statChip(l10n.countedQty, '$countedCount', color: Colors.teal),
                  _statChip(l10n.uncounted, '${_items.length - countedCount}', color: Colors.orange),
                  _statChip(l10n.variance, '$discrepantCount',
                      color: discrepantCount > 0 ? Colors.red : Colors.teal),
                ],
              ),
            ),

            // Search & Category Filters
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: l10n.searchProductsHint,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    ),
                  ),
                  if (_categories.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    DropdownButton<String?>(
                      value: _selectedCategory,
                      hint: Text(l10n.category, style: const TextStyle(fontSize: 12)),
                      items: [
                        DropdownMenuItem(value: null, child: Text(l10n.allCategories, style: const TextStyle(fontSize: 12))),
                        ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))),
                      ],
                      onChanged: (val) => setState(() => _selectedCategory = val),
                    ),
                  ],
                ],
              ),
            ),

            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  _tabChip('all', l10n.activeFilterAll),
                  const SizedBox(width: 6),
                  _tabChip('uncounted', '${l10n.uncounted} (${_items.length - countedCount})'),
                  const SizedBox(width: 6),
                  _tabChip('counted', '${l10n.countedQty} ($countedCount)'),
                  const SizedBox(width: 6),
                  _tabChip('discrepant', '${l10n.variance} ($discrepantCount)'),
                ],
              ),
            ),

            const Divider(height: 1),

            // Items List
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text(l10n.noMatchingProduct))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final it = filtered[idx];
                        final variance = it.currentVariance;
                        final hasDiscrepancy = it.isCounted && variance.abs() > 0.0001;

                        return ListTile(
                          title: Text(it.productName ?? l10n.product,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: Text(
                            '${l10n.systemQty}: ${FormatUtils.formatQuantity(it.baselineQuantity)} ${it.productUnit ?? ""} '
                            '${it.productBarcode != null ? "• ${it.productBarcode}" : ""}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    it.isCounted
                                        ? '${l10n.countedQty}: ${FormatUtils.formatQuantity(it.countedQuantity!)}'
                                        : l10n.uncounted,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: it.isCounted ? Colors.teal : Colors.orange,
                                    ),
                                  ),
                                  if (it.isCounted)
                                    Text(
                                      variance == 0
                                          ? l10n.statusMatched
                                          : '${l10n.variance}: ${variance > 0 ? "+" : ""}${FormatUtils.formatQuantity(variance)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: hasDiscrepancy
                                            ? (variance > 0 ? Colors.blue : Colors.red)
                                            : Colors.teal,
                                      ),
                                    ),
                                ],
                              ),
                              if (_session!.isActive)
                                Icon(
                                  AppIcons.chevronForward(context),
                                  size: 18,
                                ),
                            ],
                          ),
                          onTap: _session!.isActive ? () => _editItemCount(it) : null,
                        );
                      },
                    ),
            ),

            // Bottom action bar
            if (_session!.isActive)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _reviewAndFinalize,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(l10n.reviewAndFinalize),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _tabChip(String key, String label) {
    final selected = _filterTab == key;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      onSelected: (_) => setState(() => _filterTab = key),
    );
  }
}
