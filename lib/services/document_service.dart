import '../database/database_helper.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/document.dart';
import '../models/document_item.dart';
import '../utils/currency_utils.dart';

class DocumentItemInput {
  final String description;
  final double quantity;
  final double price;
  final bool taxable;
  final int? productId;

  const DocumentItemInput({
    required this.description,
    required this.quantity,
    required this.price,
    this.taxable = true,
    this.productId,
  });

  double get total => quantity * price;
}

class DocumentService {
  /// Creates a new document.
  static Future<int> createDocument({
    required String type,
    required Business business,
    Contact? contact,
    required List<DocumentItemInput> items,
    double discount = 0,
    double paid = 0,
    String? notes,
    int? relatedDocumentId,
    DateTime? date,
    DateTime? validUntil,
    String? paymentMethod,
  }) async {
    _validateBusiness(business);
    _validateTaxRate(business.taxRate);
    final documentDate = date ?? DateTime.now();

    final isFinancial = type == 'payment_receipt' || type == 'expense_voucher';
    final isInvoice = type == 'invoice';
    final isQuotation = type == 'quotation';
    final isCustom = type == 'custom';

    // Validate items and product existence *before* any contact insertion
    if (!isFinancial && !isCustom) {
      _validateItems(items);
      await _validateProductsExist(items);
    }

    if (isFinancial) {
      _validatePaymentMethod(paymentMethod, business.currencyCode);
      if (paid <= 0) {
        throw ArgumentError('Amount must be greater than zero');
      }
    }

    if (isCustom && paid < 0) {
      throw ArgumentError('Amount cannot be negative');
    }

    double subtotal = 0;
    double discountApplied = 0;
    double taxRate = 0;
    double taxAmount = 0;
    double total = 0;
    double finalPaid = 0;
    double remaining = 0;

    if (isFinancial) {
      subtotal = paid;
      finalPaid = paid;
      remaining = 0;
      total = paid;
    } else if (isQuotation) {
      if (validUntil == null || !validUntil.isAfter(documentDate)) {
        throw ArgumentError('Valid until must be after document date');
      }
      subtotal = _calculateSubtotal(items);
      discountApplied = 0;
      taxRate = business.taxRate;
      taxAmount = _calculateTax(items, discountApplied, taxRate, subtotal);
      total = subtotal + taxAmount;
      finalPaid = 0;
      remaining = total;
    } else if (isInvoice) {
      subtotal = _calculateSubtotal(items);
      discountApplied = discount;
      if (discountApplied < 0) {
        throw ArgumentError('Discount cannot be negative');
      }
      if (discountApplied > subtotal) {
        throw ArgumentError('Discount cannot exceed subtotal');
      }
      final totals = calculateInvoiceTotals(
        items: items,
        discount: discountApplied,
        taxRate: business.taxRate,
      );
      taxRate = business.taxRate;
      taxAmount = totals.taxAmount;
      total = totals.total;
      if (paid < 0) {
        throw ArgumentError('Paid amount cannot be negative');
      }
      if (paid > total) {
        throw ArgumentError('Paid amount cannot exceed total');
      }
      finalPaid = paid;
      remaining = total - finalPaid;
    } else if (isCustom) {
      subtotal = paid;
      total = paid;
      finalPaid = paid;
      remaining = 0;
    } else {
      throw ArgumentError('Unknown document type: $type');
    }

    final document = Document(
      type: type,
      documentNumber: '',
      date: documentDate,
      subtotal: subtotal,
      discount: discountApplied,
      taxRate: isFinancial || isCustom ? 0 : taxRate,
      taxAmount: isFinancial || isCustom ? 0 : taxAmount,
      total: total,
      paid: finalPaid,
      remaining: remaining,
      paymentMethod: isFinancial ? paymentMethod : null,
      validUntil: isQuotation ? validUntil : null,
      notes: notes,
      relatedDocumentId: relatedDocumentId,
      status: 'active',
      currencyCode: business.currencyCode,
    );

    final documentItems = items.map((item) => DocumentItem(
      documentId: 0,
      productId: item.productId,
      description: item.description,
      quantity: item.quantity,
      price: item.price,
      total: item.total,
      taxable: item.taxable,
    )).toList();

    final db = DatabaseHelper.instance;
    return db.insertDocumentWithItems(document, documentItems, contact: contact);
  }

  /// Updates an existing document.
  static Future<void> updateDocument({
    required int documentId,
    required String type,
    required Business business,
    Contact? contact,
    required List<DocumentItemInput> items,
    double discount = 0,
    double paid = 0,
    String? notes,
    int? relatedDocumentId,
    DateTime? date,
    DateTime? validUntil,
    String? paymentMethod,
  }) async {
    _validateBusiness(business);
    _validateTaxRate(business.taxRate);
    final db = DatabaseHelper.instance;
    final existing = await db.getDocumentById(documentId);
    if (existing == null) {
      throw ArgumentError('Document not found');
    }

    final documentDate = date ?? existing.date;
    final isFinancial = type == 'payment_receipt' || type == 'expense_voucher';
    final isInvoice = type == 'invoice';
    final isQuotation = type == 'quotation';
    final isCustom = type == 'custom';

    if (!isFinancial && !isCustom) {
      _validateItems(items);
      await _validateProductsExist(items);
    }

    if (isFinancial) {
      _validatePaymentMethod(paymentMethod, existing.currencyCode);
      if (paid <= 0) {
        throw ArgumentError('Amount must be greater than zero');
      }
    }

    if (isCustom && paid < 0) {
      throw ArgumentError('Amount cannot be negative');
    }

    double subtotal = 0;
    double discountApplied = 0;
    double taxRate = 0;
    double taxAmount = 0;
    double total = 0;
    double finalPaid = 0;
    double remaining = 0;

    if (isFinancial) {
      subtotal = paid;
      finalPaid = paid;
      remaining = 0;
      total = paid;
    } else if (isQuotation) {
      if (validUntil == null || !validUntil.isAfter(documentDate)) {
        throw ArgumentError('Valid until must be after document date');
      }
      subtotal = _calculateSubtotal(items);
      discountApplied = 0;
      taxRate = business.taxRate;
      taxAmount = _calculateTax(items, discountApplied, taxRate, subtotal);
      total = subtotal + taxAmount;
      finalPaid = 0;
      remaining = total;
    } else if (isInvoice) {
      subtotal = _calculateSubtotal(items);
      discountApplied = discount;
      if (discountApplied < 0) {
        throw ArgumentError('Discount cannot be negative');
      }
      if (discountApplied > subtotal) {
        throw ArgumentError('Discount cannot exceed subtotal');
      }
      final totals = calculateInvoiceTotals(
        items: items,
        discount: discountApplied,
        taxRate: business.taxRate,
      );
      taxRate = business.taxRate;
      taxAmount = totals.taxAmount;
      total = totals.total;
      if (paid < 0) {
        throw ArgumentError('Paid amount cannot be negative');
      }
      if (paid > total) {
        throw ArgumentError('Paid amount cannot exceed total');
      }
      finalPaid = paid;
      remaining = total - finalPaid;
    } else if (isCustom) {
      subtotal = paid;
      total = paid;
      finalPaid = paid;
      remaining = 0;
    } else {
      throw ArgumentError('Unknown document type: $type');
    }

    final effectiveRelatedDocumentId = relatedDocumentId ?? existing.relatedDocumentId;

    final updatedDocument = Document(
      id: documentId,
      type: type,
      documentNumber: existing.documentNumber,
      date: documentDate,
      contactId: contact?.id,
      recipientName: contact?.name,
      recipientPhone: contact?.phone,
      subtotal: subtotal,
      discount: discountApplied,
      taxRate: isFinancial || isCustom ? 0 : taxRate,
      taxAmount: isFinancial || isCustom ? 0 : taxAmount,
      total: total,
      paid: finalPaid,
      remaining: remaining,
      paymentMethod: isFinancial ? paymentMethod : null,
      validUntil: isQuotation ? validUntil : null,
      notes: notes,
      relatedDocumentId: effectiveRelatedDocumentId,
      status: existing.status,
      currencyCode: existing.currencyCode,
    );

    final documentItems = items.map((item) => DocumentItem(
      documentId: documentId,
      productId: item.productId,
      description: item.description,
      quantity: item.quantity,
      price: item.price,
      total: item.total,
      taxable: item.taxable,
    )).toList();

    await db.updateDocumentWithItems(updatedDocument, documentItems, contact: contact);
  }

  // ==================== Private Helpers ====================

  static void _validateBusiness(Business business) {
    if (business.id == null) {
      throw ArgumentError('Business is not saved');
    }
  }

  static void _validateTaxRate(double taxRate) {
    if (taxRate < 0 || taxRate > 100) {
      throw ArgumentError('Tax rate must be between 0 and 100');
    }
  }

  static void _validateItems(List<DocumentItemInput> items) {
    if (items.isEmpty) {
      throw ArgumentError('At least one item is required');
    }
    for (final item in items) {
      if (item.quantity <= 0) {
        throw ArgumentError('Quantity must be greater than zero');
      }
      if (item.price < 0) {
        throw ArgumentError('Price cannot be negative');
      }
      if (item.description.trim().isEmpty) {
        throw ArgumentError('Description cannot be empty');
      }
    }
  }

  static Future<void> _validateProductsExist(List<DocumentItemInput> items) async {
    final db = DatabaseHelper.instance;
    final productIds = items
        .map((item) => item.productId)
        .where((id) => id != null)
        .toSet()
        .cast<int>();
    for (final productId in productIds) {
      final product = await db.getProductById(productId);
      if (product == null) {
        throw ArgumentError('Product not found: $productId');
      }
    }
  }

  static void _validatePaymentMethod(
      String? paymentMethod, String currencyCode) {
    if (paymentMethod == null ||
        !CurrencyUtils.isPaymentMethodAllowed(paymentMethod, currencyCode)) {
      throw ArgumentError('Invalid payment method');
    }
  }

  // Updated with explicit double typing for safety
  static double _calculateSubtotal(List<DocumentItemInput> items) {
    return items.fold<double>(0.0, (sum, item) => sum + item.total);
  }

  static ({double subtotal, double taxAmount, double total})
      calculateInvoiceTotals({
    required List<DocumentItemInput> items,
    required double discount,
    required double taxRate,
  }) {
    final subtotal = _calculateSubtotal(items);
    final taxAmount = _calculateTax(items, discount, taxRate, subtotal);
    return (
      subtotal: subtotal,
      taxAmount: taxAmount,
      total: subtotal - discount + taxAmount,
    );
  }

  /// Calculates tax using proportional discount allocation:
  /// Discount is applied across taxable and non-taxable items proportionally.
  static double _calculateTax(
    List<DocumentItemInput> items,
    double discount,
    double taxRate,
    double subtotal,
  ) {
    if (subtotal <= 0) return 0;

    final taxableTotal = items
        .where((i) => i.taxable)
        .fold<double>(0.0, (sum, item) => sum + item.total);

    // If no taxable items, no tax
    if (taxableTotal <= 0) return 0;

    // Apply discount proportionally to taxable portion
    final discountRatio = (subtotal - discount) / subtotal;
    final taxableAfterDiscount = taxableTotal * discountRatio;

    if (taxableAfterDiscount < 0) return 0;
    return taxableAfterDiscount * taxRate / 100;
  }
}
