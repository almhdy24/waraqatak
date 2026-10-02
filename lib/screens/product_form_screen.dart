import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/product.dart';
import '../models/tax_profile.dart';
import '../services/product_service.dart';
import 'barcode_scanner_screen.dart';
import '../widgets/responsive.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  final String? initialBarcode;
  const ProductFormScreen({super.key, this.product, this.initialBarcode});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _unitController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _minStockController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  String _type = Product.typeProduct;
  bool _taxable = true;
  bool _isActive = true;
  bool _saving = false;
  int? _taxProfileId;
  List<TaxProfile> _taxProfiles = [];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _nameController.text = p.name;
      _type = p.type;
      _codeController.text = p.code ?? '';
      _barcodeController.text = p.barcode ?? '';
      _unitController.text = p.unit ?? '';
      _salePriceController.text = p.salePrice.toString();
      _purchasePriceController.text = p.purchasePrice.toString();
      _stockController.text = p.stockQuantity.toString();
      _minStockController.text = p.minStock.toString();
      _notesController.text = p.notes ?? '';
      _taxable = p.isTaxable;
      _isActive = p.isActive;
      _taxProfileId = p.taxProfileId;
    } else if (widget.initialBarcode != null) {
      _barcodeController.text = widget.initialBarcode!;
    }
    _loadTaxProfiles();
  }

  Future<void> _loadTaxProfiles() async {
    final profiles =
        await DatabaseHelper.instance.getTaxProfiles(activeOnly: true);
    if (mounted) setState(() => _taxProfiles = profiles);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _barcodeController.dispose();
    _unitController.dispose();
    _salePriceController.dispose();
    _purchasePriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (result != null && mounted) {
      _barcodeController.text = result;
    }
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final barcode = _barcodeController.text.trim().isEmpty
        ? null
        : _barcodeController.text.trim();

    if (barcode != null) {
      final used = await ProductService.isBarcodeUsed(
        barcode,
        excludeId: widget.product?.id,
      );
      if (used && mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).duplicateBarcode)),
        );
        return;
      }
    }

    final product = Product(
      id: widget.product?.id,
      name: _nameController.text.trim(),
      type: _type,
      code: _codeController.text.trim().isEmpty ? null : _codeController.text.trim(),
      barcode: barcode,
      unit: _unitController.text.trim().isEmpty ? null : _unitController.text.trim(),
      salePrice: double.tryParse(_salePriceController.text) ?? 0,
      purchasePrice: double.tryParse(_purchasePriceController.text) ?? 0,
      stockQuantity: _type == Product.typeService
          ? 0
          : (double.tryParse(_stockController.text) ?? 0),
      minStock: _type == Product.typeService
          ? 0
          : (double.tryParse(_minStockController.text) ?? 0),
      isTaxable: _taxable,
      isActive: _isActive,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      taxProfileId: _taxProfileId,
      createdAt: widget.product?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      int id;
      if (product.id == null) {
        id = await DatabaseHelper.instance.insertProduct(product);
      } else {
        await DatabaseHelper.instance.updateProduct(product);
        id = product.id!;
      }
      if (!mounted) return;
      Navigator.pop(context, id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).operationFailed}: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleDelete() async {
    final l10n = AppLocalizations.of(context);
    final id = widget.product!.id!;
    final referenced = await DatabaseHelper.instance.isProductReferenced(id);

    if (referenced) {
      if (!mounted) return;
      final deactivate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.deactivateProduct),
          content: Text(l10n.deactivateProductMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.deactivateProduct),
            ),
          ],
        ),
      );
      if (deactivate == true && mounted) {
        await DatabaseHelper.instance.setProductActive(id, active: false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.productDeactivated)),
        );
        Navigator.pop(context, true);
      }
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(l10n.deleteProductMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await DatabaseHelper.instance.deleteProduct(id);
        if (!mounted) return;
        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.operationFailed}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isService = _type == Product.typeService;
    final isNew = widget.product == null;
    final title = isNew
        ? (isService ? l10n.addService : l10n.addProduct)
        : (isService ? l10n.editService : l10n.editProduct);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        actions: [
          if (!isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.delete,
              onPressed: _handleDelete,
            ),
        ],
      ),
      body: ResponsiveCenter(child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.productType,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: Product.typeProduct,
                          label: Text(l10n.productItem),
                          icon: const Icon(Icons.inventory_2_outlined),
                        ),
                        ButtonSegment(
                          value: Product.typeService,
                          label: Text(l10n.serviceItem),
                          icon: const Icon(Icons.build_outlined),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: (s) => setState(() => _type = s.first),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Basic info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l10n.productName,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? l10n.required : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _codeController,
                      decoration: InputDecoration(
                        labelText: l10n.sku,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _barcodeController,
                      decoration: InputDecoration(
                        labelText: l10n.barcode,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner),
                          tooltip: l10n.scanBarcode,
                          onPressed: _scanBarcode,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _unitController,
                      decoration: InputDecoration(
                        labelText: l10n.unit,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Pricing
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.unitPrice,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _salePriceController,
                      decoration: InputDecoration(
                        labelText: l10n.unitPrice,
                        prefixIcon: const Icon(Icons.money),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        final price = double.tryParse(v ?? '');
                        if (price == null || price < 0) return l10n.invalidAmount;
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _purchasePriceController,
                      decoration: InputDecoration(
                        labelText: l10n.purchasePrice,
                        prefixIcon: const Icon(Icons.money),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Stock (products only)
            if (!isService) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.stock,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _stockController,
                        decoration: InputDecoration(
                          labelText: l10n.stockQuantity,
                          prefixIcon: const Icon(Icons.inventory_2_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _minStockController,
                        decoration: InputDecoration(
                          labelText: l10n.lowStockThreshold,
                          prefixIcon: const Icon(Icons.warning_amber_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Tax, active, notes
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      title: Text(l10n.taxable),
                      value: _taxable,
                      onChanged: (v) => setState(() => _taxable = v!),
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                    if (_taxProfiles.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int?>(
                        initialValue: _taxProfiles.any((p) => p.id == _taxProfileId)
                            ? _taxProfileId
                            : null,
                        decoration: InputDecoration(
                          labelText: l10n.taxProfile,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: [
                          DropdownMenuItem<int?>(
                              value: null, child: Text(l10n.noTaxProfile)),
                          ..._taxProfiles.map((p) => DropdownMenuItem<int?>(
                              value: p.id,
                              child: Text(
                                  '${p.name} (${p.rate.toStringAsFixed(0)}%)'))),
                        ],
                        onChanged: (v) => setState(() => _taxProfileId = v),
                      ),
                    ],
                    if (!isNew)
                      SwitchListTile(
                        title: Text(l10n.active),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: l10n.notes,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: _saving
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary),
                      )
                    : Text(l10n.save),
              ),
            ),
          ],
        ),
      )),
    );
  }
}
