import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../features/wholesale/wholesale_feature.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/currency.dart';
import '../models/document.dart';
import '../models/payment_method.dart';
import '../models/product.dart';
import '../models/product_unit.dart';
import '../services/document_service.dart';
import '../utils/error_utils.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_loading_view.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/contact_autocomplete_field.dart';
import '../widgets/discount_input_field.dart';
import '../widgets/document_item_form.dart';
import 'document_detail_screen.dart';
import '../widgets/responsive.dart';
import '../utils/number_input.dart';
import '../widgets/amount_field.dart';
import '../widgets/app_date_picker.dart';
import '../utils/date_format_utils.dart';
import '../services/access/access_guard.dart';
import '../services/access/permission_registry.dart';

class EditDocumentScreen extends StatefulWidget {
  final int documentId;
  const EditDocumentScreen({super.key, required this.documentId});

  @override
  State<EditDocumentScreen> createState() => _EditDocumentScreenState();
}

class _EditDocumentScreenState extends State<EditDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _validityKey = GlobalKey();
  final _validityFocusNode = FocusNode();

  final _notesController = TextEditingController();
  double _discount = 0.0;
  final _paidController = TextEditingController(text: '0');
  final _amountController = TextEditingController();
  final _validityDaysController = TextEditingController(text: '7');

  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  final List<TextEditingController> _productNameControllers = [];
  final List<TextEditingController> _descriptionControllers = [];
  final List<TextEditingController> _quantityControllers = [];
  final List<TextEditingController> _priceControllers = [];
  final List<bool> _taxableList = [];
  final List<int?> _productIds = [];
  final List<String?> _pricingCategories = [];
  final List<bool> _isManualPriceList = [];
  final List<Product?> _cachedProducts = [];
  final List<String?> _saleUnits = [];
  final List<double> _conversionFactors = [];
  final Map<int, List<ProductUnit>> _unitsCache = {};

  Business? _business;
  Document? _document;
  Contact? _selectedContact;
  String? _contactName;
  String _paymentMethod = 'cash';
  List<PaymentMethod> _enabledMethods = [];
  DateTime? _selectedDate;

  bool _loading = true;
  bool _loadFailed = false;
  String? _loadErrorMessage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _validityFocusNode.dispose();
    _notesController.dispose();
    _paidController.dispose();
    _amountController.dispose();
    _validityDaysController.dispose();
    _phoneController.dispose();
    _addressController.dispose();

    for (final c in _productNameControllers) {
      c.dispose();
    }
    for (final c in _descriptionControllers) {
      c.dispose();
    }
    for (final c in _quantityControllers) {
      c.dispose();
    }
    for (final c in _priceControllers) {
      c.dispose();
    }

    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
      _loadErrorMessage = null;
    });

    try {
      final db = DatabaseHelper.instance;
      final doc = await db.getDocumentById(widget.documentId);
      if (doc == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final isPurchaseDoc = doc.type == 'purchase';
      final requiredPerm = isPurchaseDoc
          ? PermissionRegistry.purchasesEdit
          : PermissionRegistry.salesEdit;
      if (!AccessGuard.can(requiredPerm)) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          AppSnackBar.show(
            context,
            l10n.accessDeniedMissingPerm(requiredPerm),
            severity: AppSnackBarSeverity.error,
          );
          Navigator.pop(context);
        }
        return;
      }

      if (doc.type == 'payment_receipt' || doc.type == 'expense_voucher') {
        final isAlloc = await db.hasActiveAllocations(doc.id!);
        if (isAlloc || doc.relatedDocumentId != null) {
          if (mounted) {
            final l10n = AppLocalizations.of(context);
            AppSnackBar.show(
              context,
              l10n.isArabic
                  ? 'لا يمكن تعديل سند تم تخصيصه. يرجى إلغاء السند وإصدار سند جديد.'
                  : 'Allocated vouchers cannot be edited. Cancel and re-issue.',
              severity: AppSnackBarSeverity.error,
            );
            Navigator.pop(context);
          }
          return;
        }
      }

      final business = await db.getFirstBusiness();
      final contact = doc.contactId != null
          ? await db.getContactById(doc.contactId!)
          : null;
      final items = await db.getDocumentItems(doc.id!);
      final enabledMethods = await db.getEnabledPaymentMethods();

      if (!mounted) return;

      _document = doc;
      _business = business;
      _enabledMethods = enabledMethods;
      _selectedContact = contact;
      _contactName = contact?.name ?? doc.recipientName;
      _phoneController.text = contact?.phone ?? doc.recipientPhone ?? '';
      _addressController.text = contact?.address ?? '';
      _selectedDate = doc.date;

      _notesController.text = doc.notes ?? '';
      _discount = doc.discount;
      _paidController.text = NumberInput.formatForInput(
        doc.paid,
        maxDecimals: 4,
      );

      if (doc.type == 'payment_receipt' || doc.type == 'expense_voucher') {
        _paymentMethod = doc.paymentMethod ?? 'cash';
        // Ensure payment method is allowed for current currency
        _ensureValidPaymentMethod();
      } else if (doc.type == 'quotation') {
        if (doc.validUntil != null) {
          final days = DocumentService.calendarDaysBetween(
            doc.date,
            doc.validUntil!,
          );
          _validityDaysController.text = NumberInput.formatForInput(
            days.toDouble(),
            maxDecimals: 0,
          );
        } else {
          _validityDaysController.text = '';
        }
      } else if (doc.type == 'custom') {
        _amountController.text = NumberInput.formatForInput(
          doc.paid,
          maxDecimals: 4,
        );
      }

      if (doc.type == 'invoice' ||
          doc.type == 'quotation' ||
          doc.type == 'purchase') {
        for (final c in _productNameControllers) {
          c.dispose();
        }
        for (final c in _descriptionControllers) {
          c.dispose();
        }
        for (final c in _quantityControllers) {
          c.dispose();
        }
        for (final c in _priceControllers) {
          c.dispose();
        }
        _productNameControllers.clear();
        _descriptionControllers.clear();
        _quantityControllers.clear();
        _priceControllers.clear();
        _taxableList.clear();
        _productIds.clear();
        _pricingCategories.clear();
        _isManualPriceList.clear();
        _cachedProducts.clear();
        _saleUnits.clear();
        _conversionFactors.clear();

        for (final item in items) {
          String name = '';
          String desc = item.description;
          if (item.productId != null) {
            name = '';
            desc = item.description;
          } else {
            if (item.description.contains('\n')) {
              final idx = item.description.indexOf('\n');
              name = item.description.substring(0, idx).trim();
              desc = item.description.substring(idx + 1).trim();
            } else {
              name = item.description;
              desc = '';
            }
          }
          _productNameControllers.add(TextEditingController(text: name));
          _descriptionControllers.add(TextEditingController(text: desc));
          _quantityControllers.add(
            TextEditingController(
              text: NumberInput.formatForInput(item.quantity, maxDecimals: 4),
            ),
          );
          _priceControllers.add(
            TextEditingController(
              text: NumberInput.formatForInput(item.price, maxDecimals: 4),
            ),
          );
          _taxableList.add(item.taxable);
          _productIds.add(item.productId);
          _pricingCategories.add(item.pricingCategory);
          _isManualPriceList.add(true);
          _cachedProducts.add(null);
          _saleUnits.add(item.saleUnit);
          _conversionFactors.add(item.unitConversionFactor);
        }
      }

      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
        _loadErrorMessage = ErrorUtils.getFriendlyErrorMessage(e);
      });
    }
  }

  void _ensureValidPaymentMethod() {
    if (_enabledMethods.isEmpty) return;
    if (!_enabledMethods.any((m) => m.key == _paymentMethod)) {
      _paymentMethod = _enabledMethods.first.key;
    }
  }

  void _addItem() {
    _hasChanges = true;
    setState(() {
      _productNameControllers.add(TextEditingController());
      _descriptionControllers.add(TextEditingController());
      _quantityControllers.add(TextEditingController(text: '1'));
      _priceControllers.add(TextEditingController());
      _taxableList.add(true);
      _productIds.add(null);
      _pricingCategories.add(
        WholesaleFeature.isEnabledForBusiness(_business)
            ? (_selectedContact?.pricingCategory ?? Contact.categoryRetail)
            : null,
      );
      _isManualPriceList.add(false);
      _cachedProducts.add(null);
      _saleUnits.add(null);
      _conversionFactors.add(1.0);
    });
  }

  bool _hasChanges = false;

  Future<bool> _onWillPop() async {
    if (!_hasChanges || _saving) return true;
    final l10n = AppLocalizations.of(context);
    return AppConfirmDialog.show(
      context,
      title: l10n.unsavedChangesTitle,
      message: l10n.unsavedChangesMessage,
      confirmLabel: l10n.discardChanges,
      isDestructive: true,
    );
  }

  Future<void> _removeItem(int index) async {
    FocusScope.of(context).unfocus();
    final hasContent =
        _descriptionControllers[index].text.isNotEmpty ||
        _productIds[index] != null;
    if (hasContent) {
      final l10n = AppLocalizations.of(context);
      final proceed = await AppConfirmDialog.show(
        context,
        title: l10n.confirmDeleteLine,
        message: l10n.deleteLineWarning,
        isDestructive: true,
      );
      if (!proceed) return;
    }
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    _hasChanges = true;
    final nameCtrl = _productNameControllers.removeAt(index);
    final descCtrl = _descriptionControllers.removeAt(index);
    final qtyCtrl = _quantityControllers.removeAt(index);
    final priceCtrl = _priceControllers.removeAt(index);
    setState(() {
      _taxableList.removeAt(index);
      _productIds.removeAt(index);
      _pricingCategories.removeAt(index);
      _isManualPriceList.removeAt(index);
      _cachedProducts.removeAt(index);
      _saleUnits.removeAt(index);
      _conversionFactors.removeAt(index);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameCtrl.dispose();
      descCtrl.dispose();
      qtyCtrl.dispose();
      priceCtrl.dispose();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final isQuoPreCheck = _document?.type == 'quotation';
    if (!_formKey.currentState!.validate()) {
      if (isQuoPreCheck) {
        final days = NumberInput.parse(_validityDaysController.text)?.toInt();
        if (days == null || days < 1) {
          if (_validityKey.currentContext != null) {
            Scrollable.ensureVisible(
              _validityKey.currentContext!,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
          _validityFocusNode.requestFocus();
        }
      }
      return;
    }
    if (_document == null || _business == null) return;

    setState(() => _saving = true);

    final type = _document!.type;
    final isInvoice = type == 'invoice';
    final isQuotation = type == 'quotation';
    final isPurchase = type == 'purchase';
    final isFinancial = type == 'payment_receipt' || type == 'expense_voucher';
    final isCustom = type == 'custom';

    Contact? contact;
    if (_selectedContact != null) {
      contact = _selectedContact;
    } else if (_contactName != null && _contactName!.trim().isNotEmpty) {
      contact = Contact(
        name: _contactName!.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        type: (type == 'expense_voucher' || isPurchase)
            ? 'supplier'
            : 'customer',
      );
    }

    final items = <DocumentItemInput>[];
    if (isInvoice || isQuotation || isPurchase) {
      for (int i = 0; i < _descriptionControllers.length; i++) {
        final name = i < _productNameControllers.length
            ? _productNameControllers[i].text.trim()
            : '';
        final desc = _descriptionControllers[i].text.trim();
        final effectiveDesc =
            (name.isNotEmpty && desc.isNotEmpty && name != desc)
                ? '$name\n$desc'
                : (name.isNotEmpty ? name : desc);
        final q = NumberInput.parse(_quantityControllers[i].text) ?? 0;
        final factor = i < _conversionFactors.length
            ? _conversionFactors[i]
            : 1.0;
        final unit = i < _saleUnits.length ? _saleUnits[i] : null;
        items.add(
          DocumentItemInput(
            description: effectiveDesc,
            quantity: q,
            price: NumberInput.parse(_priceControllers[i].text) ?? 0,
            taxable: _taxableList[i],
            productId: _productIds[i],
            pricingCategory: _pricingCategories[i],
            saleUnit: unit,
            unitConversionFactor: factor,
            baseQuantity: q * factor,
          ),
        );
      }
    }

    double discount = 0;
    double paid = 0;
    if (isInvoice || isPurchase || isQuotation) {
      discount = _discount;
    }
    if (isInvoice || isPurchase) {
      paid = NumberInput.parse(_paidController.text) ?? 0;
    } else if (isFinancial) {
      paid = NumberInput.parse(_paidController.text) ?? 0;
    } else if (isCustom) {
      paid = NumberInput.parse(_amountController.text) ?? 0;
    }

    DateTime? validUntil;
    if (isQuotation) {
      final days = NumberInput.parse(_validityDaysController.text)?.toInt();
      if (days == null || days < 1) {
        if (_validityKey.currentContext != null) {
          Scrollable.ensureVisible(
            _validityKey.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
        _validityFocusNode.requestFocus();
        return;
      }
      final docDate = _selectedDate ?? _document!.date;
      validUntil = docDate.add(Duration(days: days));
    }

    String? finalPaymentMethod;
    if (isFinancial) {
      if (_enabledMethods.isNotEmpty &&
          !_enabledMethods.any((m) => m.key == _paymentMethod)) {
        _paymentMethod = _enabledMethods.first.key;
      }
      finalPaymentMethod = _paymentMethod;
    }

    try {
      await DocumentService.updateDocument(
        documentId: widget.documentId,
        type: type,
        business: _business!,
        contact: contact,
        recipientName: _selectedContact?.name ?? _contactName,
        recipientPhone: _selectedContact?.phone ??
            (_phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim()),
        items: items,
        discount: discount,
        paid: paid,
        notes: _notesController.text.trim(),
        date: _selectedDate,
        validUntil: validUntil,
        paymentMethod: finalPaymentMethod,
        relatedDocumentId: _document!.relatedDocumentId,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentDetailScreen(documentId: widget.documentId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        ErrorUtils.getFriendlyErrorMessage(
          e,
          l10n: AppLocalizations.of(context),
        ),
        severity: AppSnackBarSeverity.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double get _subtotal {
    double sum = 0;
    for (int i = 0; i < _descriptionControllers.length; i++) {
      final q = NumberInput.parse(_quantityControllers[i].text) ?? 0;
      final p = NumberInput.parse(_priceControllers[i].text) ?? 0;
      sum += q * p;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (_loading) {
      return const Scaffold(body: AppLoadingView());
    }

    if (_loadFailed || _document == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.edit)),
        body: AppErrorState(
          message: _loadErrorMessage ?? l10n.operationFailed,
          onRetry: _load,
        ),
      );
    }

    final type = _document!.type;
    final isInvoice = type == 'invoice';
    final isQuotation = type == 'quotation';
    final isPurchase = type == 'purchase';
    final isFinancial = type == 'payment_receipt' || type == 'expense_voucher';
    final isCustom = type == 'custom';
    final isSupplier = type == 'expense_voucher' || isPurchase;

    final allowedMethods = _enabledMethods;

    return PopScope(
      canPop: !_hasChanges || _saving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final proceed = await _onWillPop();
        if (proceed && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${l10n.edit} - ${_document!.documentNumber}'),
          centerTitle: true,
        ),
        body: ResponsiveCenter(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!isFinancial) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSupplier ? l10n.supplier : l10n.customer,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ContactAutocompleteField(
                            initialContact: _selectedContact,
                            label: isSupplier ? l10n.supplier : l10n.customer,
                            type: isSupplier ? 'supplier' : 'customer',
                            onContactChanged: (contact) async {
                              setState(() {
                                _selectedContact = contact;
                                _contactName = contact?.name;
                                _phoneController.text = contact?.phone ?? '';
                                _addressController.text =
                                    contact?.address ?? '';
                              });
                              if (WholesaleFeature.isEnabledForBusiness(
                                    _business,
                                  ) &&
                                  !isPurchase) {
                                final newCat =
                                    contact?.pricingCategory ??
                                    Contact.categoryRetail;
                                for (
                                  int i = 0;
                                  i < _descriptionControllers.length;
                                  i++
                                ) {
                                  final p = _cachedProducts[i];
                                  if (!_isManualPriceList[i] && p != null) {
                                    _pricingCategories[i] = newCat;
                                    final q =
                                        NumberInput.parse(
                                          _quantityControllers[i].text,
                                        ) ??
                                        1.0;
                                    final currentP = NumberInput.parse(
                                      _priceControllers[i].text,
                                    );
                                    List<ProductUnit> units =
                                        _unitsCache[p.id] ?? const [];
                                    if (units.isEmpty && p.id != null) {
                                      try {
                                        units = await DatabaseHelper.instance
                                            .getProductUnits(p.id!);
                                        _unitsCache[p.id!] = units;
                                      } catch (_) {}
                                    }
                                    final resolved =
                                        DocumentService.resolveLinePrice(
                                          product: p,
                                          availableUnits: units,
                                          quantity: q,
                                          currentPrice: currentP,
                                          saleUnit: _saleUnits[i],
                                          unitConversionFactor:
                                              _conversionFactors[i],
                                          pricingCategory:
                                              _pricingCategories[i],
                                          targetCategory: newCat,
                                          isManualPrice: _isManualPriceList[i],
                                          wholesalePricingEnabled: true,
                                        );
                                    _priceControllers[i].text =
                                        NumberInput.formatForInput(
                                          resolved,
                                          maxDecimals: 4,
                                        );
                                  }
                                }
                                if (mounted) setState(() {});
                              }
                            },
                            onTextChanged: (value) {
                              if (_selectedContact?.name != value) {
                                _selectedContact = null;
                              }
                              _contactName = value;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(labelText: l10n.phone),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _addressController,
                            decoration: InputDecoration(
                              labelText: l10n.address,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type == 'expense_voucher'
                                ? l10n.supplier
                                : l10n.customer,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ContactAutocompleteField(
                            initialContact: _selectedContact,
                            label: type == 'expense_voucher'
                                ? l10n.paidTo
                                : l10n.receivedFrom,
                            type: type == 'expense_voucher'
                                ? 'supplier'
                                : 'customer',
                            onContactChanged: (contact) {
                              setState(() {
                                _selectedContact = contact;
                                _contactName = contact?.name;
                              });
                            },
                            onTextChanged: (value) {
                              if (_selectedContact?.name != value) {
                                _selectedContact = null;
                              }
                              _contactName = value;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (isFinancial) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.amount,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          AmountField(
                            controller: _paidController,
                            maxDecimals: 4,
                            showMultipliers: true,
                            decoration: InputDecoration(
                              labelText: l10n.amount,
                              prefixIcon: const Icon(Icons.money),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) {
                              final amount = NumberInput.parse(v ?? '');
                              if (amount == null || amount <= 0) {
                                return l10n.invalidAmount;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.paymentMethod,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: allowedMethods.map((method) {
                              return _paymentChip(
                                method.key,
                                method.label(l10n.langCode),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(labelText: l10n.reason),
                  ),
                ],

                if (isInvoice || isQuotation || isPurchase) ...[
                  Text(
                    l10n.products,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(
                    _descriptionControllers.length,
                    (index) => DocumentItemForm(
                      key: ObjectKey(_descriptionControllers[index]),
                      productNameController:
                          index < _productNameControllers.length
                              ? _productNameControllers[index]
                              : null,
                      descriptionController: _descriptionControllers[index],
                      quantityController: _quantityControllers[index],
                      priceController: _priceControllers[index],
                      taxable: _taxableList[index],
                      productId: _productIds[index],
                      usePurchasePrice: isPurchase,
                      wholesalePricingEnabled:
                          WholesaleFeature.isEnabledForBusiness(_business),
                      pricingCategory: _pricingCategories[index],
                      onPricingCategoryChanged: (cat) {
                        setState(() => _pricingCategories[index] = cat);
                      },
                      customerPricingCategory:
                          _selectedContact?.pricingCategory ??
                          Contact.categoryRetail,
                      isManualPrice: _isManualPriceList[index],
                      onManualPriceChanged: (manual) {
                        setState(() => _isManualPriceList[index] = manual);
                      },
                      saleUnit: _saleUnits[index],
                      onSaleUnitChanged: (unit) {
                        setState(() => _saleUnits[index] = unit);
                      },
                      unitConversionFactor: _conversionFactors[index],
                      onConversionFactorChanged: (factor) {
                        setState(() => _conversionFactors[index] = factor);
                      },
                      onProductChanged: (productId) {
                        setState(() => _productIds[index] = productId);
                      },
                      onProductSelected: (p) {
                        setState(() => _cachedProducts[index] = p);
                        if (p?.id != null) {
                          DatabaseHelper.instance.getProductUnits(p!.id!).then((
                            u,
                          ) {
                            _unitsCache[p.id!] = u;
                          });
                        }
                      },
                      onTaxableChanged: (value) {
                        setState(() => _taxableList[index] = value ?? true);
                      },
                      onDelete: () => _removeItem(index),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.products),
                  ),
                  const Divider(),
                  if (isInvoice || isPurchase || isQuotation) ...[
                    DiscountInputField(
                      subtotal: _subtotal,
                      currencySymbol: _business?.currencySymbol ?? '',
                      decimalDigits: Currency.decimalDigitsForCode(
                        _business?.currencyCode,
                      ),
                      initialDiscount: _discount,
                      onDiscountChanged: (d) => setState(() => _discount = d),
                    ),
                    if (!isQuotation) ...[
                      const SizedBox(height: 8),
                      AmountField(
                        controller: _paidController,
                        maxDecimals: 4,
                        showMultipliers: true,
                        decoration: InputDecoration(labelText: l10n.paid),
                      ),
                    ],
                  ],
                  if (isQuotation) ...[
                    Builder(
                      builder: (ctx) {
                        final days =
                            NumberInput.parse(_validityDaysController.text)
                                ?.toInt() ??
                            7;
                        final effectiveDays = days > 0 ? days : 7;
                        final docDate = _selectedDate ?? _document!.date;
                        final expiryDate =
                            docDate.add(Duration(days: effectiveDays));
                        return AmountField(
                          key: _validityKey,
                          controller: _validityDaysController,
                          focusNode: _validityFocusNode,
                          maxDecimals: 0,
                          showMultipliers: false,
                          validator: (v) {
                            final d = NumberInput.parse(v ?? '')?.toInt();
                            if (d == null || d <= 0) {
                              return l10n.errorValidityMinDays;
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: l10n.validityDays,
                            hintText: l10n.validityHint,
                            helperText:
                                '${l10n.validUntil}: ${AppDateUtils.formatDate(expiryDate)}',
                            helperStyle: TextStyle(
                              color: Theme.of(ctx).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: IconButton(
                              icon: const Icon(
                                Icons.calendar_month_outlined,
                                size: 20,
                              ),
                              tooltip: l10n.selectDate,
                              onPressed: () async {
                                final picked = await AppDatePicker.show(
                                  context: ctx,
                                  initialDate: expiryDate,
                                  firstDate:
                                      docDate.add(const Duration(days: 1)),
                                  lastDate:
                                      docDate.add(const Duration(days: 3650)),
                                );
                                if (picked != null) {
                                  final diff =
                                      DocumentService.calendarDaysBetween(
                                        docDate,
                                        picked,
                                      );
                                  final pickedDays = diff > 0 ? diff : 1;
                                  _validityDaysController.text =
                                      pickedDays.toString();
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(labelText: l10n.notes),
                  ),
                ],

                if (isCustom) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.amount,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          AmountField(
                            controller: _amountController,
                            maxDecimals: 4,
                            showMultipliers: true,
                            decoration: InputDecoration(
                              labelText: l10n.amount,
                              prefixIcon: const Icon(Icons.money),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              final amount = NumberInput.parse(v);
                              if (amount == null || amount < 0) {
                                return l10n.invalidAmount;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.date,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  AppDateUtils.formatDate(_selectedDate!),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final picked = await AppDatePicker.show(
                                    context: context,
                                    initialDate: _selectedDate!,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null && mounted) {
                                    setState(() => _selectedDate = picked);
                                  }
                                },
                                child: Text(l10n.edit),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: l10n.notes),
                  ),
                ],

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
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : Text(l10n.saveChanges),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _paymentMethod == value,
      onSelected: (selected) {
        if (selected) setState(() => _paymentMethod = value);
      },
      selectedColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.15),
      backgroundColor: Theme.of(context).colorScheme.surface,
      labelStyle: TextStyle(
        color: _paymentMethod == value
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: _paymentMethod == value
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}
