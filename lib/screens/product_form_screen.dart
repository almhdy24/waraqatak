import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/product.dart';
import '../models/product_unit.dart';
import '../models/tax_profile.dart';
import '../services/feature_access.dart';
import '../services/license_service.dart';
import '../services/product_service.dart';
import '../utils/error_utils.dart';
import '../utils/format_utils.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_design_tokens.dart';
import '../widgets/pro_upgrade_sheet.dart';
import '../widgets/responsive.dart';
import 'barcode_scanner_screen.dart';
import 'inventory_screen.dart';

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
  final _wholesalePriceController = TextEditingController();
  final _wholesaleMinQuantityController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _minStockController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  final _categoryController = TextEditingController();

  String _type = Product.typeProduct;
  bool _taxable = true;
  bool _isActive = true;
  bool _saving = false;
  int? _taxProfileId;
  List<TaxProfile> _taxProfiles = [];
  List<String> _existingCategories = [];
  double _currentStock = 0;
  List<ProductUnit> _productUnits = [];
  bool _wholesalePricingEnabled = false;

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
      _categoryController.text = p.category ?? '';
      _salePriceController.text = p.salePrice.toString();
      _wholesalePriceController.text = p.wholesalePrice?.toString() ?? '';
      _wholesaleMinQuantityController.text = p.wholesaleMinQuantity != null
          ? FormatUtils.formatQuantity(p.wholesaleMinQuantity)
          : '';
      _purchasePriceController.text = p.purchasePrice.toString();
      _currentStock = p.stockQuantity;
      _stockController.text = FormatUtils.formatQuantity(p.stockQuantity);
      _minStockController.text =
          p.minStock > 0 ? FormatUtils.formatQuantity(p.minStock) : '0';
      _notesController.text = p.notes ?? '';
      _taxable = p.isTaxable;
      _isActive = p.isActive;
      _taxProfileId = p.taxProfileId;
      if (p.id != null) {
        _loadProductUnits(p.id!);
      }
    } else if (widget.initialBarcode != null) {
      _barcodeController.text = widget.initialBarcode!;
    }
    _loadTaxProfiles();
    _loadCategories();
    _loadWholesaleStatus();
  }

  Future<void> _loadProductUnits(int productId) async {
    try {
      final units = await DatabaseHelper.instance.getProductUnits(productId);
      if (mounted) setState(() => _productUnits = units);
    } catch (_) {}
  }

  Future<void> _loadWholesaleStatus() async {
    try {
      final b = await DatabaseHelper.instance.getFirstBusiness();
      if (mounted) {
        setState(() => _wholesalePricingEnabled = b?.wholesalePricingEnabled ?? false);
      }
    } catch (_) {}
  }

  Future<void> _loadTaxProfiles() async {
    try {
      final profiles =
          await DatabaseHelper.instance.getTaxProfiles(activeOnly: true);
      if (mounted) setState(() => _taxProfiles = profiles);
    } catch (_) {}
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await DatabaseHelper.instance.getProductCategories();
      if (mounted) setState(() => _existingCategories = categories);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _barcodeController.dispose();
    _unitController.dispose();
    _categoryController.dispose();
    _salePriceController.dispose();
    _wholesalePriceController.dispose();
    _wholesaleMinQuantityController.dispose();
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

  Future<void> _handleStockAdjustment() async {
    final entitlement = await LicenseService.instance.checkEntitlement();
    if (!mounted) return;
    if (!FeatureAccess.canAccess(Feature.inventory, entitlement)) {
      await ProUpgradeSheet.show(context, feature: Feature.inventory);
      return;
    }
    final adjusted =
        await InventoryScreen.showAdjustDialog(context, widget.product!);
    if (adjusted && mounted) {
      final updated =
          await DatabaseHelper.instance.getProductById(widget.product!.id!);
      if (updated != null && mounted) {
        setState(() {
          _currentStock = updated.stockQuantity;
          _stockController.text =
              FormatUtils.formatQuantity(updated.stockQuantity);
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final isNew = widget.product == null;
    if (!isNew &&
        widget.product!.isProduct &&
        _type == Product.typeService &&
        _currentStock > 0) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                AppLocalizations.of(context).cannotConvertStockedProductToService)),
      );
      return;
    }

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
      wholesalePrice: _wholesalePricingEnabled
          ? double.tryParse(_wholesalePriceController.text.trim())
          : widget.product?.wholesalePrice,
      wholesaleMinQuantity: _wholesalePricingEnabled
          ? double.tryParse(_wholesaleMinQuantityController.text.trim())
          : widget.product?.wholesaleMinQuantity,
      purchasePrice: double.tryParse(_purchasePriceController.text) ?? 0,
      stockQuantity: isNew
          ? (_type == Product.typeService
              ? 0
              : (double.tryParse(_stockController.text) ?? 0))
          : _currentStock,
      minStock: _type == Product.typeService
          ? 0
          : (double.tryParse(_minStockController.text) ?? 0),
      isTaxable: _taxable,
      isActive: _isActive,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
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
      await DatabaseHelper.instance.syncProductUnits(id, _productUnits);
      if (!mounted) return;
      Navigator.pop(context, id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e, l10n: AppLocalizations.of(context)))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showUnitDialog([ProductUnit? existing, int? index]) async {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: existing?.unitName ?? '');
    final factorCtrl = TextEditingController(
      text: existing != null
          ? FormatUtils.formatQuantity(existing.conversionFactor)
          : '',
    );
    final saleCtrl = TextEditingController(
      text: existing?.salePrice?.toString() ?? '',
    );
    final wholesaleCtrl = TextEditingController(
      text: existing?.wholesalePrice?.toString() ?? '',
    );
    bool isDefault = existing?.isDefaultSale ?? false;
    final formKey = GlobalKey<FormState>();

    final res = await showDialog<ProductUnit>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(existing == null ? l10n.addSalesUnit : l10n.editSalesUnit),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.salesUnitName,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? l10n.required : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: factorCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.conversionFactor,
                      helperText: l10n.conversionFactorHelp,
                      helperMaxLines: 2,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return l10n.required;
                      final f = double.tryParse(v.trim());
                      if (f == null || f <= 0) {
                        return l10n.invalidConversionFactor;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: saleCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '${l10n.unitPrice} (${l10n.optional})',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (_wholesalePricingEnabled) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: wholesaleCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: '${l10n.wholesalePrice} (${l10n.optional})',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: Text(l10n.defaultSaleUnit),
                    value: isDefault,
                    onChanged: (val) =>
                        setDlgState(() => isDefault = val ?? false),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final unit = ProductUnit(
                    id: existing?.id,
                    productId: widget.product?.id ?? 0,
                    unitName: nameCtrl.text.trim(),
                    conversionFactor: double.parse(factorCtrl.text.trim()),
                    salePrice: double.tryParse(saleCtrl.text.trim()),
                    wholesalePrice: _wholesalePricingEnabled
                        ? double.tryParse(wholesaleCtrl.text.trim())
                        : null,
                    isDefaultSale: isDefault,
                  );
                  Navigator.pop(ctx, unit);
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );

    if (res != null) {
      setState(() {
        if (res.isDefaultSale) {
          _productUnits = _productUnits
              .map((u) => u.copyWith(isDefaultSale: false))
              .toList();
        }
        if (index != null) {
          _productUnits[index] = res;
        } else {
          _productUnits.add(res);
        }
      });
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
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.confirmDelete,
      message: l10n.deleteProductMessage,
      confirmLabel: l10n.delete,
      isDestructive: true,
    );

    if (confirmed && mounted) {
      try {
        await DatabaseHelper.instance.deleteProduct(id);
        if (!mounted) return;
        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e, l10n: l10n))),
        );
      }
    }
  }

  bool get _isDirty {
    if (widget.product == null) {
      return _nameController.text.isNotEmpty ||
          _codeController.text.isNotEmpty ||
          _barcodeController.text.isNotEmpty ||
          _unitController.text.isNotEmpty ||
          _categoryController.text.isNotEmpty ||
          _salePriceController.text.isNotEmpty ||
          _wholesalePriceController.text.isNotEmpty ||
          _purchasePriceController.text.isNotEmpty ||
          _stockController.text != '0' ||
          _minStockController.text != '0' ||
          _notesController.text.isNotEmpty ||
          _productUnits.isNotEmpty;
    }
    final p = widget.product!;
    return _nameController.text != p.name ||
        _type != p.type ||
        _codeController.text != (p.code ?? '') ||
        _barcodeController.text != (p.barcode ?? '') ||
        _unitController.text != (p.unit ?? '') ||
        _categoryController.text != (p.category ?? '') ||
        _salePriceController.text != p.salePrice.toString() ||
        _wholesalePriceController.text != (p.wholesalePrice?.toString() ?? '') ||
        _purchasePriceController.text != p.purchasePrice.toString() ||
        _taxable != p.isTaxable ||
        _taxProfileId != p.taxProfileId ||
        _isActive != p.isActive ||
        _notesController.text != (p.notes ?? '');
  }

  Future<bool> _onWillPop() async {
    if (!_isDirty || _saving) return true;
    final l10n = AppLocalizations.of(context);
    return AppConfirmDialog.show(
      context,
      title: l10n.unsavedChangesTitle,
      message: l10n.unsavedChangesMessage,
      confirmLabel: l10n.discardChanges,
      isDestructive: true,
    );
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

    return PopScope(
      canPop: !_isDirty || _saving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final proceed = await _onWillPop();
        if (proceed && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
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
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7)),
              ),
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
                      onSelectionChanged: (s) {
                        final newType = s.first;
                        if (!isNew &&
                            widget.product!.isProduct &&
                            newType == Product.typeService &&
                            _currentStock > 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  l10n.cannotConvertStockedProductToService),
                            ),
                          );
                          return;
                        }
                        setState(() => _type = newType);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Basic info
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7)),
              ),
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
                    const SizedBox(height: 12),
                    RawAutocomplete<String>(
                      textEditingController: _categoryController,
                      focusNode: FocusNode(),
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return _existingCategories;
                        }
                        return _existingCategories.where(
                          (c) => c.toLowerCase().contains(textEditingValue.text.toLowerCase()),
                        );
                      },
                      onSelected: (selection) {
                        _categoryController.text = selection;
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: l10n.category,
                            hintText: l10n.categoryHint,
                            prefixIcon: const Icon(Icons.category_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: AlignmentDirectional.topStart,
                          child: Material(
                            elevation: 4.0,
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final option = options.elementAt(index);
                                  return InkWell(
                                    onTap: () => onSelected(option),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Text(option),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Pricing
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7)),
              ),
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
                    if (_wholesalePricingEnabled) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _wholesalePriceController,
                        decoration: InputDecoration(
                          labelText: l10n.wholesalePrice,
                          prefixIcon: const Icon(Icons.storefront_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final price = double.tryParse(v);
                          if (price == null || price < 0) return l10n.invalidAmount;
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _wholesaleMinQuantityController,
                        decoration: InputDecoration(
                          labelText: l10n.wholesaleMinQuantity,
                          helperText: l10n.wholesaleMinQuantityHelp,
                          prefixIcon: const Icon(Icons.format_list_numbered),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final q = double.tryParse(v);
                          if (q == null || q < 0) return l10n.invalidQuantity;
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _purchasePriceController,
                      decoration: InputDecoration(
                        labelText: l10n.purchasePrice,
                        prefixIcon: const Icon(Icons.money),
                        helperText: l10n.purchasePriceCostHelp,
                        helperMaxLines: 2,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Additional Sales Units
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
                side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.7),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.additionalSalesUnits,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _showUnitDialog(),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(l10n.addSalesUnit),
                        ),
                      ],
                    ),
                    if (_productUnits.isEmpty)
                      Text(
                        l10n.noUnits,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 13,
                        ),
                      )
                    else
                      ..._productUnits.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final u = entry.value;
                        final baseName = _unitController.text.trim().isNotEmpty
                            ? _unitController.text.trim()
                            : l10n.baseUnit;
                        final desc =
                            '1 ${u.unitName} = ${FormatUtils.formatQuantity(u.conversionFactor)} $baseName';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Row(
                            children: [
                              Text(
                                u.unitName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (u.isDefaultSale) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    l10n.defaultSaleUnit,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(desc),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: l10n.edit,
                                onPressed: () => _showUnitDialog(u, idx),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete_outline, size: 18),
                                tooltip: l10n.delete,
                                onPressed: () {
                                  setState(() => _productUnits.removeAt(idx));
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Stock (products only)
            if (!isService) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7)),
                ),
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
                        readOnly: !isNew,
                        decoration: InputDecoration(
                          labelText: isNew
                              ? l10n.openingStock
                              : l10n.stockQuantity,
                          prefixIcon: const Icon(Icons.inventory_2_outlined),
                          helperText: isNew
                              ? l10n.openingStockHelp
                              : l10n.stockCannotBeEditedDirectly,
                          helperMaxLines: 2,
                          suffixIcon: !isNew
                              ? IconButton(
                                  icon: const Icon(Icons.tune),
                                  tooltip: l10n.stockAdjustment,
                                  onPressed: _handleStockAdjustment,
                                )
                              : null,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _minStockController,
                        decoration: InputDecoration(
                          labelText: l10n.lowStockThreshold,
                          prefixIcon:
                              const Icon(Icons.warning_amber_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Tax, active, notes
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7)),
              ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDesignTokens.buttonRadius),
                  ),
                ),
                child: _saving
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary),
                      )
                    : Text(
                        isNew
                            ? (isService ? l10n.saveService : l10n.saveProduct)
                            : l10n.saveChanges,
                      ),
              ),
            ),
          ],
        ),
      )),
      ),
    );
  }
}
