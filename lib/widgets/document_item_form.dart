import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/product.dart';
import '../screens/barcode_scanner_screen.dart';
import '../screens/product_form_screen.dart';
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
  });

  @override
  State<DocumentItemForm> createState() => _DocumentItemFormState();
}

class _DocumentItemFormState extends State<DocumentItemForm> {
  int? _selectedProductId;

  @override
  void initState() {
    super.initState();
    _selectedProductId = widget.productId;
  }

  @override
  void didUpdateWidget(covariant DocumentItemForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _selectedProductId = widget.productId;
    }
  }

  void _onProductSelected(Product? product) {
    if (product == null) return;
    final price = widget.usePurchasePrice
        ? product.purchasePrice
        : product.salePrice;
    setState(() {
      _selectedProductId = product.id;
      widget.descriptionController.text = product.name;
      widget.priceController.text = price.toStringAsFixed(2);
      widget.onTaxableChanged(product.isTaxable);
    });
    widget.onProductChanged(product.id);
    widget.onProductSelected?.call(product);
    widget.onChanged?.call();
  }

  void _clearProduct() {
    setState(() => _selectedProductId = null);
    widget.onProductChanged(null);
    widget.onProductSelected?.call(null);
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
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 16,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.descriptionController.text,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
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
                    onChanged: (_) => widget.onChanged?.call(),
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
                    onChanged: (_) => widget.onChanged?.call(),
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
