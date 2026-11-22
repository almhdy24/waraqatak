import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/catalog_events.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/product.dart';
import '../services/access/audit_service.dart';
import '../services/bulk_pricing_service.dart';
import '../services/feature_access.dart';
import '../services/license_service.dart';
import '../utils/arabic_search_utils.dart';
import '../utils/error_utils.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/pro_upgrade_sheet.dart';
import '../widgets/responsive.dart';
import '../utils/number_input.dart';
import '../widgets/amount_field.dart';

class BulkPricingScreen extends StatefulWidget {
  const BulkPricingScreen({super.key});

  @override
  State<BulkPricingScreen> createState() => _BulkPricingScreenState();
}

class _BulkPricingScreenState extends State<BulkPricingScreen> {
  List<Product> _allProducts = [];
  List<String> _categories = [];
  String? _selectedCategory;
  final String _selectedType = 'all'; // all, product, service
  String _searchQuery = '';

  final Set<int> _selectedProductIds = {};
  Set<int> _productIdsWithCustomUnits = {};
  BulkPriceOpType _opType = BulkPriceOpType.percentageIncrease;
  BulkPriceTarget _target = BulkPriceTarget.sellingPrice;
  BulkPriceRounding _rounding = BulkPriceRounding.none;
  final _valController = TextEditingController(text: '10');

  Map<int, BulkPricePreviewItem> _previewMap = {};
  bool _loading = true;
  String? _error;

  static final _numFmt = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _checkEntitlementAndLoad();
  }

  @override
  void dispose() {
    _valController.dispose();
    super.dispose();
  }

  Future<void> _checkEntitlementAndLoad() async {
    final entitlement = await LicenseService.instance.checkEntitlement(
      force: true,
    );
    if (!mounted) return;
    if (!FeatureAccess.canAccess(Feature.bulkPriceUpdate, entitlement)) {
      if (mounted) {
        final activated = await ProUpgradeSheet.show(
          context,
          feature: Feature.bulkPriceUpdate,
        );
        if (activated && mounted) {
          final updated =
              await LicenseService.instance.checkEntitlement(force: true);
          if (FeatureAccess.canAccess(Feature.bulkPriceUpdate, updated)) {
            await _load();
            return;
          }
        }
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

      final prodRows = await db.query(
        'products',
        where: 'is_active = 1',
        orderBy: 'name ASC',
      );
      _allProducts = prodRows.map((r) => Product.fromMap(r)).toList();

      final unitRows = await db.rawQuery(
        'SELECT DISTINCT product_id FROM product_units',
      );
      if (!mounted) return;
      _productIdsWithCustomUnits = {
        for (final r in unitRows)
          if (r['product_id'] != null) r['product_id'] as int,
      };

      // Do not select all products by default
      _selectedProductIds.clear();

      _updatePreview();
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorUtils.getFriendlyErrorMessage(e);
        _loading = false;
      });
    }
  }

  void _updatePreview() {
    final val = NumberInput.parse(_valController.text.trim()) ?? 0.0;
    final items = BulkPricingService.instance.preview(
      products: _allProducts,
      opType: _opType,
      opValue: val,
      target: _target,
      rounding: _rounding,
    );
    _previewMap = {
      for (final it in items)
        if (it.product.id != null) it.product.id!: it,
    };
  }

  Future<void> _applyChanges() async {
    final l10n = AppLocalizations.of(context);
    final val = NumberInput.parse(_valController.text.trim());
    if (val == null || val < 0) {
      AppSnackBar.show(
        context,
        l10n.invalidPriceWarning,
        severity: AppSnackBarSeverity.warning,
      );
      return;
    }

    final selectedItems = _selectedProductIds
        .map((id) => _previewMap[id])
        .whereType<BulkPricePreviewItem>()
        .toList();

    if (selectedItems.isEmpty) return;

    final hasErrors = selectedItems.any((it) => !it.isValid);
    if (hasErrors) {
      AppSnackBar.show(
        context,
        l10n.invalidPriceWarning,
        severity: AppSnackBarSeverity.error,
      );
      return;
    }

    final hasCustomUnits = selectedItems.any(
      (it) =>
          it.product.id != null &&
          _productIdsWithCustomUnits.contains(it.product.id!),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmPriceUpdate),
        content: Text(
          '${l10n.selectProducts}: ${selectedItems.length}\n'
          '${l10n.operationType}: ${_getOpLabel(_opType, l10n)} ($val)\n'
          '${l10n.targetPrice}: ${_getTargetLabel(_target, l10n)}'
          '${hasCustomUnits ? '\n\n${l10n.bulkPricingCustomUnitsWarning}' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.applyChanges),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed == true) {
      final revertSnapshots = selectedItems.map((it) => it.product).toList();
      setState(() => _loading = true);
      try {
        final result = await BulkPricingService.instance.applyBatch(
          items: selectedItems,
          opType: _opType,
          opValue: val,
          target: _target,
        );
        if (!mounted) return;
        await _load();
        if (!mounted) return;
        if (result.affectedCount > 0) {
          final message = result.skippedCount > 0
              ? '${l10n.pricesUpdatedSuccess} (${l10n.bulkSkippedReference(result.skippedCount)})'
              : l10n.pricesUpdatedSuccess;
          AppSnackBar.showUndo(
            context,
            message,
            actionLabel: l10n.undo,
            onUndo: () => _undoPriceChanges(revertSnapshots),
          );
        } else if (result.skippedCount > 0) {
          AppSnackBar.show(
            context,
            l10n.bulkSkippedReference(result.skippedCount),
            severity: AppSnackBarSeverity.info,
          );
        }
      } catch (e) {
        if (!mounted) return;
        AppSnackBar.show(
          context,
          ErrorUtils.getFriendlyErrorMessage(e, l10n: l10n),
          severity: AppSnackBarSeverity.error,
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _undoPriceChanges(List<Product> previousSnapshots) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _loading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        final now = DateTime.now().toIso8601String();
        for (final p in previousSnapshots) {
          if (p.id == null) continue;
          await txn.update(
            'products',
            {
              'sale_price': p.salePrice,
              'purchase_price': p.purchasePrice,
              'wholesale_price': p.wholesalePrice,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [p.id],
          );
        }
        await AuditService.instance.logEvent(
          txn,
          'bulk_pricing_undo',
          entityType: 'products_batch',
          entityId: previousSnapshots.length,
          details:
              'reverted ${previousSnapshots.length} products to previous prices',
        );
      });
      CatalogEvents.notifyPricesChanged();
      if (!mounted) return;
      AppSnackBar.show(
        context,
        l10n.operationSuccessful,
        severity: AppSnackBarSeverity.success,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        ErrorUtils.getFriendlyErrorMessage(e, l10n: l10n),
        severity: AppSnackBarSeverity.error,
      );
      setState(() => _loading = false);
    }
  }

  String _getOpLabel(BulkPriceOpType op, AppLocalizations l10n) {
    switch (op) {
      case BulkPriceOpType.percentageIncrease:
        return l10n.percentageIncrease;
      case BulkPriceOpType.percentageDecrease:
        return l10n.percentageDecrease;
      case BulkPriceOpType.fixedIncrease:
        return l10n.fixedIncrease;
      case BulkPriceOpType.fixedDecrease:
        return l10n.fixedDecrease;
      case BulkPriceOpType.setDirect:
        return l10n.setNewPrice;
    }
  }

  String _getTargetLabel(BulkPriceTarget target, AppLocalizations l10n) {
    switch (target) {
      case BulkPriceTarget.sellingPrice:
        return l10n.sellingPrice;
      case BulkPriceTarget.purchasePrice:
        return l10n.purchasePrice;
      case BulkPriceTarget.wholesalePrice:
        return l10n.wholesalePrice;
      case BulkPriceTarget.both:
        return l10n.bothPrices;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.bulkPricingTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.bulkPricingTitle)),
        body: Center(child: Text(_error!)),
      );
    }

    final filteredProducts = _allProducts.where((p) {
      if (_selectedCategory != null && p.category != _selectedCategory) {
        return false;
      }
      if (_selectedType != 'all' && p.type != _selectedType) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.trim();
        final matchName = ArabicSearchUtils.matches(p.name, q);
        final matchBarcode = ArabicSearchUtils.matches(p.barcode, q);
        final matchCode = ArabicSearchUtils.matches(p.code, q);
        if (!matchName && !matchBarcode && !matchCode) return false;
      }
      return true;
    }).toList();

    final allFilteredSelected =
        filteredProducts.isNotEmpty &&
        filteredProducts.every((p) => _selectedProductIds.contains(p.id));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bulkPricingTitle)),
      body: ResponsiveCenter(
        child: Column(
          children: [
            // Config Card
            Card(
              margin: const EdgeInsets.all(12),
              elevation: 0,
              color: cs.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Operation Type
                        Expanded(
                          child: DropdownButtonFormField<BulkPriceOpType>(
                            decoration: InputDecoration(
                              labelText: l10n.operationType,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                            initialValue: _opType,
                            items: BulkPriceOpType.values.map((op) {
                              return DropdownMenuItem(
                                value: op,
                                child: Text(
                                  _getOpLabel(op, l10n),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _opType = val;
                                  _updatePreview();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Value
                        Builder(
                          builder: (context) {
                            final isPercent =
                                _opType == BulkPriceOpType.percentageIncrease ||
                                _opType == BulkPriceOpType.percentageDecrease;
                            return SizedBox(
                              width: 100,
                              child: AmountField(
                                controller: _valController,
                                maxDecimals: 4,
                                showMultipliers: false,
                                decoration: InputDecoration(
                                  labelText: l10n.value,
                                  suffixText: isPercent ? '%' : null,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                ),
                                onChanged: (_) => setState(_updatePreview),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Target Price
                        Expanded(
                          child: DropdownButtonFormField<BulkPriceTarget>(
                            decoration: InputDecoration(
                              labelText: l10n.targetPrice,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                            initialValue: _target,
                            items: BulkPriceTarget.values.map((t) {
                              return DropdownMenuItem(
                                value: t,
                                child: Text(
                                  _getTargetLabel(t, l10n),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _target = val;
                                  _updatePreview();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Rounding Rule
                        Expanded(
                          child: DropdownButtonFormField<BulkPriceRounding>(
                            decoration: InputDecoration(
                              labelText: l10n.roundingRule,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                            initialValue: _rounding,
                            items: [
                              DropdownMenuItem(
                                value: BulkPriceRounding.none,
                                child: Text(
                                  l10n.roundNone,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DropdownMenuItem(
                                value: BulkPriceRounding.nearestWhole,
                                child: Text(
                                  l10n.roundNearestWhole,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DropdownMenuItem(
                                value: BulkPriceRounding.nearestTen,
                                child: Text(
                                  l10n.roundNearestTen,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DropdownMenuItem(
                                value: BulkPriceRounding.ceilWhole,
                                child: Text(
                                  l10n.roundUp,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _rounding = val;
                                  _updatePreview();
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (_categories.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text(
                        l10n.allCategories,
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: _selectedCategory == null,
                      onSelected: (_) => setState(() {
                        _selectedCategory = null;
                      }),
                    ),
                    const SizedBox(width: 6),
                    ..._categories.map(
                      (c) => Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: ChoiceChip(
                          label: Text(c, style: const TextStyle(fontSize: 11)),
                          selected: _selectedCategory == c,
                          onSelected: (_) => setState(() {
                            _selectedCategory = c;
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Selection & Search Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Checkbox(
                    value: allFilteredSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          for (final p in filteredProducts) {
                            if (p.id != null) _selectedProductIds.add(p.id!);
                          }
                        } else {
                          for (final p in filteredProducts) {
                            if (p.id != null) _selectedProductIds.remove(p.id!);
                          }
                        }
                      });
                    },
                  ),
                  Text(
                    '${l10n.selectProducts} (${_selectedProductIds.length}/${_allProducts.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Search field
                  SizedBox(
                    width: 140,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: l10n.search,
                        prefixIcon: const Icon(Icons.search, size: 16),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (val) =>
                          setState(() => _searchQuery = val.trim()),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            if (_selectedProductIds.any(
              (id) => _productIdsWithCustomUnits.contains(id),
            ))
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.bulkPricingCustomUnitsWarning,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Preview List
            Expanded(
              child: filteredProducts.isEmpty
                  ? Center(child: Text(l10n.noMatchingProduct))
                  : ListView.separated(
                      itemCount: filteredProducts.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final product = filteredProducts[idx];
                        final item = _previewMap[product.id];
                        final isSelected = _selectedProductIds.contains(
                          product.id,
                        );

                        final double oldDisplayPrice;
                        final double newDisplayPrice;
                        if (_target == BulkPriceTarget.purchasePrice) {
                          oldDisplayPrice =
                              item?.currentPurchasePrice ??
                              product.purchasePrice;
                          newDisplayPrice =
                              item?.proposedPurchasePrice ??
                              product.purchasePrice;
                        } else if (_target == BulkPriceTarget.wholesalePrice) {
                          oldDisplayPrice =
                              item?.currentWholesalePrice ??
                              product.wholesalePrice ??
                              0.0;
                          newDisplayPrice =
                              item?.proposedWholesalePrice ??
                              product.wholesalePrice ??
                              0.0;
                        } else {
                          oldDisplayPrice =
                              item?.currentSalePrice ?? product.salePrice;
                          newDisplayPrice =
                              item?.proposedSalePrice ?? product.salePrice;
                        }
                        final delta = newDisplayPrice - oldDisplayPrice;
                        final isPercent =
                            _opType == BulkPriceOpType.percentageIncrease ||
                            _opType == BulkPriceOpType.percentageDecrease;
                        final pctSuffix = (isPercent && oldDisplayPrice > 0)
                            ? ' (${delta >= 0 ? "+" : ""}${_numFmt.format((delta / oldDisplayPrice) * 100)}%)'
                            : '';

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                if (product.id != null) {
                                  _selectedProductIds.add(product.id!);
                                }
                              } else {
                                if (product.id != null) {
                                  _selectedProductIds.remove(product.id!);
                                }
                              }
                            });
                          },
                          title: Text(
                            product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            '${l10n.currentPrice}: ${_numFmt.format(oldDisplayPrice)}${product.unit != null && product.unit!.isNotEmpty ? " / ${product.unit}" : ""} ${product.category != null ? "• ${product.category}" : ""}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          secondary: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${l10n.proposedPrice}: ${_numFmt.format(newDisplayPrice)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: (item?.isValid ?? true)
                                      ? cs.primary
                                      : cs.error,
                                ),
                              ),
                              Text(
                                '${delta >= 0 ? "+" : ""}${_numFmt.format(delta)}$pctSuffix',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: delta >= 0 ? cs.tertiary : cs.error,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Bottom Apply Action
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surface,
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _selectedProductIds.isNotEmpty
                          ? _applyChanges
                          : null,
                      icon: const Icon(Icons.check),
                      label: Text(
                        '${l10n.applyChanges} (${_selectedProductIds.length})',
                      ),
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
}
