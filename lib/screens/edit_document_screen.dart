import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/document.dart';
import '../models/payment_method.dart';
import '../models/product.dart';
import '../services/document_service.dart';
import '../utils/error_utils.dart';
import '../widgets/contact_autocomplete_field.dart';
import '../widgets/document_item_form.dart';
import 'document_detail_screen.dart';
import '../widgets/responsive.dart';

class EditDocumentScreen extends StatefulWidget {
  final int documentId;
  const EditDocumentScreen({super.key, required this.documentId});

  @override
  State<EditDocumentScreen> createState() => _EditDocumentScreenState();
}

class _EditDocumentScreenState extends State<EditDocumentScreen> {
  final _formKey = GlobalKey<FormState>();

  final _notesController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _paidController = TextEditingController(text: '0');
  final _amountController = TextEditingController();
  final _validityDaysController = TextEditingController(text: '7');

  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

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

  Business? _business;
  Document? _document;
  Contact? _selectedContact;
  String? _contactName;
  String _paymentMethod = 'cash';
  List<PaymentMethod> _enabledMethods = [];
  DateTime? _selectedDate;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _discountController.dispose();
    _paidController.dispose();
    _amountController.dispose();
    _validityDaysController.dispose();
    _phoneController.dispose();
    _addressController.dispose();

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
    setState(() => _loading = true);

    final db = DatabaseHelper.instance;
    final doc = await db.getDocumentById(widget.documentId);
    if (doc == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final business = await db.getFirstBusiness();
    final contact = doc.contactId != null ? await db.getContactById(doc.contactId!) : null;
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
    _discountController.text = doc.discount == doc.discount.roundToDouble()
        ? doc.discount.toInt().toString()
        : doc.discount.toString();
    _paidController.text = doc.paid == doc.paid.roundToDouble()
        ? doc.paid.toInt().toString()
        : doc.paid.toString();

    if (doc.type == 'payment_receipt' || doc.type == 'expense_voucher') {
      _paymentMethod = doc.paymentMethod ?? 'cash';
      // Ensure payment method is allowed for current currency
      _ensureValidPaymentMethod();
    } else if (doc.type == 'quotation') {
      if (doc.validUntil != null) {
        final days = doc.validUntil!.difference(doc.date).inDays;
        _validityDaysController.text = days.toString();
      }
    } else if (doc.type == 'custom') {
      _amountController.text = doc.paid.toString();
    }

    if (doc.type == 'invoice' || doc.type == 'quotation' || doc.type == 'purchase') {
      for (final item in items) {
        _descriptionControllers.add(TextEditingController(text: item.description));
        _quantityControllers.add(TextEditingController(
            text: item.quantity % 1 == 0
                ? item.quantity.toInt().toString()
                : item.quantity.toString()));
        _priceControllers.add(TextEditingController(
            text: item.price % 1 == 0
                ? item.price.toInt().toString()
                : item.price.toString()));
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
  }

  void _ensureValidPaymentMethod() {
    if (_enabledMethods.isEmpty) return;
    if (!_enabledMethods.any((m) => m.key == _paymentMethod)) {
      _paymentMethod = _enabledMethods.first.key;
    }
  }

  void _addItem() {
    setState(() {
      _descriptionControllers.add(TextEditingController());
      _quantityControllers.add(TextEditingController(text: '1'));
      _priceControllers.add(TextEditingController());
      _taxableList.add(true);
      _productIds.add(null);
      _pricingCategories.add(
        _business?.wholesalePricingEnabled == true
            ? (_selectedContact?.pricingCategory ?? Contact.categoryRetail)
            : null,
      );
      _isManualPriceList.add(false);
      _cachedProducts.add(null);
      _saleUnits.add(null);
      _conversionFactors.add(1.0);
    });
  }

  void _removeItem(int index) {
    setState(() {
      _descriptionControllers[index].dispose();
      _quantityControllers[index].dispose();
      _priceControllers[index].dispose();

      _descriptionControllers.removeAt(index);
      _quantityControllers.removeAt(index);
      _priceControllers.removeAt(index);
      _taxableList.removeAt(index);
      _productIds.removeAt(index);
      _pricingCategories.removeAt(index);
      _isManualPriceList.removeAt(index);
      _cachedProducts.removeAt(index);
      _saleUnits.removeAt(index);
      _conversionFactors.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
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
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        type: (type == 'expense_voucher' || isPurchase) ? 'supplier' : 'customer',
      );
    }

    final items = <DocumentItemInput>[];
    if (isInvoice || isQuotation || isPurchase) {
      for (int i = 0; i < _descriptionControllers.length; i++) {
        final q = double.parse(_quantityControllers[i].text);
        final factor = i < _conversionFactors.length ? _conversionFactors[i] : 1.0;
        final unit = i < _saleUnits.length ? _saleUnits[i] : null;
        items.add(
          DocumentItemInput(
            description: _descriptionControllers[i].text.trim(),
            quantity: q,
            price: double.parse(_priceControllers[i].text),
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
    if (isInvoice || isPurchase) {
      discount = double.tryParse(_discountController.text) ?? 0;
      paid = double.tryParse(_paidController.text) ?? 0;
    } else if (isFinancial) {
      paid = double.tryParse(_paidController.text) ?? 0;
    } else if (isCustom) {
      paid = double.tryParse(_amountController.text) ?? 0;
    }

    DateTime? validUntil;
    if (isQuotation) {
      final days = int.tryParse(_validityDaysController.text) ?? 0;
      validUntil = (_selectedDate ?? _document!.date).add(Duration(days: days));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorUtils.getFriendlyErrorMessage(e, l10n: AppLocalizations.of(context))),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final type = _document!.type;
    final isInvoice = type == 'invoice';
    final isQuotation = type == 'quotation';
    final isPurchase = type == 'purchase';
    final isFinancial = type == 'payment_receipt' || type == 'expense_voucher';
    final isCustom = type == 'custom';
    final isSupplier = type == 'expense_voucher' || isPurchase;

    final allowedMethods = _enabledMethods;

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.edit} - ${_document!.documentNumber}'),
        centerTitle: true,
      ),
      body: ResponsiveCenter(child: Form(
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      ContactAutocompleteField(
                        initialContact: _selectedContact,
                        label: isSupplier ? l10n.supplier : l10n.customer,
                        type: isSupplier ? 'supplier' : 'customer',
                        onContactChanged: (contact) {
                          setState(() {
                            _selectedContact = contact;
                            _contactName = contact?.name;
                            _phoneController.text = contact?.phone ?? '';
                            _addressController.text = contact?.address ?? '';
                            if (_business?.wholesalePricingEnabled == true && !isPurchase) {
                              final newCat =
                                  contact?.pricingCategory ?? Contact.categoryRetail;
                              for (int i = 0; i < _descriptionControllers.length; i++) {
                                if (!_isManualPriceList[i] && _cachedProducts[i] != null) {
                                  _pricingCategories[i] = newCat;
                                  final q = double.tryParse(_quantityControllers[i].text) ?? 1.0;
                                  final resolved = DocumentService.resolveItemPrice(
                                    product: _cachedProducts[i]!,
                                    targetCategory: newCat,
                                    quantity: q,
                                    wholesalePricingEnabled: true,
                                  );
                                  _priceControllers[i].text = resolved.toStringAsFixed(2);
                                }
                              }
                            }
                          });
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
                        decoration: InputDecoration(labelText: l10n.address),
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
                        type == 'expense_voucher' ? l10n.supplier : l10n.customer,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      ContactAutocompleteField(
                        initialContact: _selectedContact,
                        label: type == 'expense_voucher' ? l10n.paidTo : l10n.receivedFrom,
                        type: type == 'expense_voucher' ? 'supplier' : 'customer',
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
                      Text(l10n.amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _paidController,
                        decoration: InputDecoration(
                          labelText: l10n.amount,
                          prefixIcon: const Icon(Icons.money),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          final amount = double.tryParse(v ?? '');
                          if (amount == null || amount <= 0) return l10n.invalidAmount;
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(l10n.paymentMethod, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: allowedMethods.map((method) {
                          return _paymentChip(method.key, method.label(l10n.langCode));
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
              Text(l10n.products, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...List.generate(
                _descriptionControllers.length,
                (index) => DocumentItemForm(
                  descriptionController: _descriptionControllers[index],
                  quantityController: _quantityControllers[index],
                  priceController: _priceControllers[index],
                  taxable: _taxableList[index],
                  productId: _productIds[index],
                  usePurchasePrice: isPurchase,
                  wholesalePricingEnabled:
                      _business?.wholesalePricingEnabled ?? false,
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
              if (isInvoice || isPurchase) ...[
                TextFormField(
                  controller: _discountController,
                  decoration: InputDecoration(labelText: l10n.discount),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _paidController,
                  decoration: InputDecoration(labelText: l10n.paid),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
              if (isQuotation) ...[
                TextFormField(
                  controller: _validityDaysController,
                  decoration: InputDecoration(labelText: l10n.validityDays),
                  keyboardType: TextInputType.number,
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
                      Text(l10n.amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: l10n.amount,
                          prefixIcon: const Icon(Icons.money),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) return null;
                          final amount = double.tryParse(v);
                          if (amount == null || amount < 0) return l10n.invalidAmount;
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(l10n.date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate!)),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
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
                    ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                    : Text(l10n.saveChanges),
              ),
            ),
          ],
        ),
      )),
    );
  }

  Widget _paymentChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _paymentMethod == value,
      onSelected: (selected) {
        if (selected) setState(() => _paymentMethod = value);
      },
      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
      backgroundColor: Theme.of(context).colorScheme.surface,
      labelStyle: TextStyle(
        color: _paymentMethod == value ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: _paymentMethod == value ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }

}
