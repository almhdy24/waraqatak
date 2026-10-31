import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/contact.dart';
import '../models/product.dart';
import '../models/product_unit.dart';
import '../screens/barcode_scanner_screen.dart';
import '../screens/product_form_screen.dart';
import '../services/document_service.dart';
import '../utils/format_utils.dart';
import 'product_autocomplete_field.dart';

class DocumentItemForm extends StatefulWidget {
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  final bool taxable;
  final double? taxRate;
  final ValueChanged<bool?> onTaxableChanged;
  final int? productId;
  final ValueChanged<int?> onProductChanged;
  final ValueChanged<Product?>? onProductSelected;
  final VoidCallback onDelete;
  final VoidCallback? onChanged;
  final bool usePurchasePrice;
  final bool wholesalePricingEnabled;
  final String? pricingCategory;
  final ValueChanged<String?>? onPricingCategoryChanged;
  final String customerPricingCategory;
  final bool isManualPrice;
  final ValueChanged<bool>? onManualPriceChanged;
  final String? saleUnit;
  final ValueChanged<String?>? onSaleUnitChanged;
  final double unitConversionFactor;
  final ValueChanged<double>? onConversionFactorChanged;

  const DocumentItemForm({
    super.key,
    required this.descriptionController,
    required this.quantityController,
    required this.priceController,
    required this.taxable,
    this.taxRate,
    required this.onTaxableChanged,
    this.productId,
    required this.onProductChanged,
    this.onProductSelected,
    required this.onDelete,
    this.onChanged,
    this.usePurchasePrice = false,
    this.wholesalePricingEnabled = false,
    this.pricingCategory,
    this.onPricingCategoryChanged,
    this.customerPricingCategory = Contact.categoryRetail,
    this.isManualPrice = false,
    this.onManualPriceChanged,
    this.saleUnit,
    this.onSaleUnitChanged,
    this.unitConversionFactor = 1.0,
    this.onConversionFactorChanged,
  });

  @override
  State<DocumentItemForm> createState() => _DocumentItemFormState();
}

class _DocumentItemFormState extends State<DocumentItemForm> {
  int? _selectedProductId;
  Product? _selectedProduct;
  List<ProductUnit> _availableUnits = [];
  ProductUnit? _selectedUnit;

  @override
  void initState() {
    super.initState();
    _selectedProductId = widget.productId;
    if (widget.productId != null) {
      _loadProduct(widget.productId!);
    }
  }

  @override
  void didUpdateWidget(covariant DocumentItemForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _selectedProductId = widget.productId;
      if (widget.productId != null) {
        _loadProduct(widget.productId!);
      } else {
        _selectedProduct = null;
        _availableUnits = [];
        _selectedUnit = null;
      }
    }
  }

  Future<void> _loadProduct(int id) async {
    final p = await DatabaseHelper.instance.getProductById(id);
    final units = await DatabaseHelper.instance.getProductUnits(id);
    if (mounted && _selectedProductId == id) {
      ProductUnit? matchedUnit;
      if (widget.saleUnit != null && widget.saleUnit!.isNotEmpty) {
        matchedUnit =
            units.where((u) => u.unitName == widget.saleUnit).firstOrNull;
      }
      setState(() {
        _selectedProduct = p;
        _availableUnits = units;
        _selectedUnit = matchedUnit;
      });
    }
  }

  void _onProductSelected(Product? product) async {
    if (product == null) return;
    _selectedProduct = product;
    final units = await DatabaseHelper.instance.getProductUnits(product.id!);
    final defaultUnit = units.where((u) => u.isDefaultSale).firstOrNull;
    _availableUnits = units;
    _selectedUnit = defaultUnit;

    if (defaultUnit != null) {
      widget.onSaleUnitChanged?.call(defaultUnit.unitName);
      widget.onConversionFactorChanged?.call(defaultUnit.conversionFactor);
    } else {
      widget.onSaleUnitChanged?.call(product.unit);
      widget.onConversionFactorChanged?.call(1.0);
    }

    double price;
    if (widget.usePurchasePrice) {
      price = product.purchasePrice;
    } else {
      final tier = widget.pricingCategory ?? widget.customerPricingCategory;
      if (widget.wholesalePricingEnabled) {
        widget.onPricingCategoryChanged?.call(tier);
      }
      widget.onManualPriceChanged?.call(false);
      final q = double.tryParse(widget.quantityController.text) ?? 1.0;
      price = DocumentService.resolveItemPrice(
        product: product,
        targetCategory: tier,
        quantity: q,
        wholesalePricingEnabled: widget.wholesalePricingEnabled,
        unit: _selectedUnit,
      );
    }

    if (mounted) {
      setState(() {
        _selectedProductId = product.id;
        widget.descriptionController.text = product.name;
        widget.priceController.text = price.toStringAsFixed(2);
        widget.onTaxableChanged(product.isTaxable);
      });
    }
    widget.onProductChanged(product.id);
    widget.onProductSelected?.call(product);
    widget.onChanged?.call();
  }

  void _onUnitSelected(ProductUnit? unit) {
    setState(() => _selectedUnit = unit);
    widget.onSaleUnitChanged?.call(unit?.unitName ?? _selectedProduct?.unit);
    widget.onConversionFactorChanged?.call(unit?.conversionFactor ?? 1.0);
    if (!widget.usePurchasePrice &&
        !widget.isManualPrice &&
        _selectedProduct != null) {
      final q = double.tryParse(widget.quantityController.text) ?? 1.0;
      final tier = widget.pricingCategory ?? widget.customerPricingCategory;
      final resolved = DocumentService.resolveItemPrice(
        product: _selectedProduct!,
        targetCategory: tier,
        quantity: q,
        wholesalePricingEnabled: widget.wholesalePricingEnabled,
        unit: unit,
      );
      widget.priceController.text = resolved.toStringAsFixed(2);
    }
    widget.onChanged?.call();
  }

  void _clearProduct() {
    setState(() {
      _selectedProductId = null;
      _selectedProduct = null;
      _availableUnits = [];
      _selectedUnit = null;
    });
    widget.onProductChanged(null);
    widget.onProductSelected?.call(null);
    widget.onSaleUnitChanged?.call(null);
    widget.onConversionFactorChanged?.call(1.0);
    widget.onChanged?.call();
  }

  void _applyTier(String tier) {
    widget.onManualPriceChanged?.call(false);
    widget.onPricingCategoryChanged?.call(tier);
    if (_selectedProduct != null) {
      final q = double.tryParse(widget.quantityController.text) ?? 1.0;
      final resolved = DocumentService.resolveItemPrice(
        product: _selectedProduct!,
        targetCategory: tier,
        quantity: q,
        wholesalePricingEnabled: true,
        unit: _selectedUnit,
      );
      widget.priceController.text = resolved.toStringAsFixed(2);
    }
    widget.onChanged?.call();
  }

  void _onQuantityChanged(String value) {
    if (!widget.usePurchasePrice &&
        !widget.isManualPrice &&
        _selectedProduct != null) {
      final q = double.tryParse(value) ?? 0.0;
      final tier = widget.pricingCategory ?? widget.customerPricingCategory;
      final resolved = DocumentService.resolveItemPrice(
        product: _selectedProduct!,
        targetCategory: tier,
        quantity: q,
        wholesalePricingEnabled: widget.wholesalePricingEnabled,
        unit: _selectedUnit,
      );
      final currentP = double.tryParse(widget.priceController.text) ?? 0.0;
      if ((resolved - currentP).abs() > 0.0001) {
        widget.priceController.text = resolved.toStringAsFixed(2);
      }
    }
    widget.onChanged?.call();
  }

  Future<void> _scanAndLookup(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || !context.mounted) return;

    final product = await DatabaseHelper.instance.getProductByBarcode(code);
    if (product != null) {
      _onProductSelected(product);
      return;
    }

    if (!context.mounted) return;
    final create = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.barcodeNotFound),
        content: Text(code),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.createFromBarcode),
          ),
        ],
      ),
    );

    if (create == true && context.mounted) {
      final newId = await Navigator.push<int>(
        context,
        MaterialPageRoute(
          builder: (_) => ProductFormScreen(initialBarcode: code),
        ),
      );
      if (newId != null && context.mounted) {
        final created = await DatabaseHelper.instance.getProductById(newId);
        if (created != null) _onProductSelected(created);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final qty = double.tryParse(widget.quantityController.text) ?? 0.0;
    final price = double.tryParse(widget.priceController.text) ?? 0.0;
    final lineTotal = qty * price;

    String taxBadgeLabel;
    if (!widget.taxable) {
      taxBadgeLabel = l10n.itemNonTaxable;
    } else if (widget.taxRate != null) {
      taxBadgeLabel =
          '${l10n.itemTaxable} (${FormatUtils.formatTaxRate(widget.taxRate!)})';
    } else {
      taxBadgeLabel = l10n.itemTaxable;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedProductId == null)
              Row(
                children: [
                  Expanded(
                    child: ProductAutocompleteField(
                      label: l10n.productName,
                      onProductSelected: _onProductSelected,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: l10n.scanBarcode,
                    onPressed: () => _scanAndLookup(context),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.descriptionController.text.isNotEmpty
                            ? widget.descriptionController.text
                            : l10n.item,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: _clearProduct,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            TextFormField(
              controller: widget.descriptionController,
              decoration: InputDecoration(
                labelText: l10n.itemDescription,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? l10n.required : null,
              onChanged: (_) => widget.onChanged?.call(),
            ),
            if (widget.wholesalePricingEnabled && !widget.usePurchasePrice) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${l10n.pricingTier}:',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(l10n.linePriceRetail, style: const TextStyle(fontSize: 11)),
                    selected: widget.pricingCategory == Contact.categoryRetail && !widget.isManualPrice,
                    onSelected: (selected) {
                      if (selected) {
                        _applyTier(Contact.categoryRetail);
                      }
                    },
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: Text(l10n.linePriceWholesale, style: const TextStyle(fontSize: 11)),
                    selected: widget.pricingCategory == Contact.categoryWholesale && !widget.isManualPrice,
                    onSelected: (selected) {
                      if (selected) {
                        _applyTier(Contact.categoryWholesale);
                      }
                    },
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  if (widget.isManualPrice || widget.pricingCategory == null) ...[
                    const SizedBox(width: 6),
                    Chip(
                      label: Text(l10n.linePriceManual, style: const TextStyle(fontSize: 11)),
                      backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ],
              ),
            ],
            if (_selectedProduct != null && _availableUnits.isNotEmpty && !widget.usePurchasePrice) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text(
                      '${l10n.salesUnit}:',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(
                        _selectedProduct!.unit?.isNotEmpty == true
                            ? _selectedProduct!.unit!
                            : l10n.baseUnit,
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: _selectedUnit == null,
                      onSelected: (selected) {
                        if (selected) _onUnitSelected(null);
                      },
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    ..._availableUnits.map((u) {
                      final isSel = _selectedUnit?.id == u.id ||
                          (_selectedUnit != null && _selectedUnit!.unitName == u.unitName);
                      return Padding(
                        padding: const EdgeInsetsDirectional.only(start: 6),
                        child: ChoiceChip(
                          label: Text(u.unitName, style: const TextStyle(fontSize: 11)),
                          selected: isSel,
                          onSelected: (selected) {
                            if (selected) _onUnitSelected(u);
                          },
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: widget.quantityController,
                    decoration: InputDecoration(
                      labelText: l10n.itemQuantity,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      final q = double.tryParse(v ?? '');
                      if (q == null || q <= 0) return l10n.invalidQuantity;
                      return null;
                    },
                    onChanged: _onQuantityChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: widget.priceController,
                    decoration: InputDecoration(
                      labelText: l10n.itemPrice,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      final p = double.tryParse(v ?? '');
                      if (p == null || p < 0) return l10n.invalidAmount;
                      return null;
                    },
                    onChanged: (val) {
                      widget.onManualPriceChanged?.call(true);
                      widget.onChanged?.call();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                InkWell(
                  onTap: () {
                    widget.onTaxableChanged(!widget.taxable);
                    widget.onChanged?.call();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: widget.taxable
                          ? cs.primaryContainer.withValues(alpha: 0.6)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.taxable
                            ? cs.primary.withValues(alpha: 0.3)
                            : cs.outlineVariant,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.taxable
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 16,
                          color: widget.taxable
                              ? cs.primary
                              : cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          taxBadgeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: widget.taxable
                                ? cs.primary
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (lineTotal > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${l10n.lineTotal}: ${lineTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                  ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: cs.error, size: 20),
                  tooltip: l10n.delete,
                  onPressed: widget.onDelete,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
