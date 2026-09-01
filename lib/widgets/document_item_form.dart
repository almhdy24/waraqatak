import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../models/product.dart';
import 'product_autocomplete_field.dart';

class DocumentItemForm extends StatefulWidget {
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  final bool taxable;
  final ValueChanged<bool?> onTaxableChanged;
  final int? productId;
  final ValueChanged<int?> onProductChanged;
  final VoidCallback onDelete;
  final VoidCallback? onChanged; // ✅ جديد: يستدعي عند تغيير الكمية أو السعر

  const DocumentItemForm({
    super.key,
    required this.descriptionController,
    required this.quantityController,
    required this.priceController,
    required this.taxable,
    required this.onTaxableChanged,
    this.productId,
    required this.onProductChanged,
    required this.onDelete,
    this.onChanged,
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
    setState(() {
      _selectedProductId = product.id;
      widget.descriptionController.text = product.name;
      widget.priceController.text = product.salePrice.toStringAsFixed(2);
      widget.onTaxableChanged(product.isTaxable);
    });
    widget.onProductChanged(product.id);
    widget.onChanged?.call();
  }

  void _clearProduct() {
    setState(() => _selectedProductId = null);
    widget.onProductChanged(null);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            if (_selectedProductId == null)
              ProductAutocompleteField(
                label: l10n.productName,
                onProductSelected: _onProductSelected,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.descriptionController.text,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearProduct,
                  ),
                ],
              ),
            TextFormField(
              controller: widget.descriptionController,
              decoration: InputDecoration(labelText: l10n.itemDescription),
              validator: (v) => v == null || v.isEmpty ? l10n.required : null,
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: widget.quantityController,
                    decoration: InputDecoration(labelText: l10n.itemQuantity),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final qty = double.tryParse(v ?? '');
                      if (qty == null || qty <= 0) return l10n.invalidQuantity;
                      return null;
                    },
                    onChanged: (_) => widget.onChanged?.call(), // ✅ تحديث فوري
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: widget.priceController,
                    decoration: InputDecoration(labelText: l10n.itemPrice),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final price = double.tryParse(v ?? '');
                      if (price == null || price < 0) return l10n.invalidAmount;
                      return null;
                    },
                    onChanged: (_) => widget.onChanged?.call(), // ✅ تحديث فوري
                  ),
                ),
                Checkbox(
                  value: widget.taxable,
                  onChanged: (v) {
                    widget.onTaxableChanged(v);
                    widget.onChanged?.call();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}