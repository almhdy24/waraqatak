import '../database/database_helper.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/document.dart';
import '../models/document_item.dart';
import '../models/document_status.dart';

class DocumentItemInput {
  final String description;
  final double quantity;
  final double price;
  final bool taxable;
  final int? productId;
  final double? taxRate; // per-item rate snapshot; null = use business default

  const DocumentItemInput({
    required this.description,
    required this.quantity,
    required this.price,
    this.taxable = true,
    this.productId,
    this.taxRate,
  });

  double get total => quantity * price;
}

class DocumentService {
  /// Creates a new document.
  /// [isDraft] — if true, the document is saved as a draft (invoice/quotation only);
  /// stock is not deducted and the document is excluded from financial summaries.
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
    bool isDraft = false,
  }) async {
    _validateBusiness(business);
    _validateTaxRate(business.taxRate);
    final documentDate = date ?? DateTime.now();

    final isFinancial = type == 'payment_receipt' || type == 'expense_voucher';
    final isInvoice = type == 'invoice';
    final isPurchase = type == 'purchase';
    final isQuotation = type == 'quotation';
    final isCustom = type == 'custom';

    // Validate items and product existence *before* any contact insertion
    if (!isFinancial && !isCustom) {
      _validateItems(items);
      await _validateProductsExist(items);
    }

    if (isFinancial) {
      _validatePaymentMethod(paymentMethod);
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
      taxAmount = _calculateTaxMultiRate(
          items, discountApplied, taxRate, subtotal, business.pricesIncludeTax);
      total = business.pricesIncludeTax ? subtotal : subtotal + taxAmount;
      finalPaid = 0;
      remaining = total;
    } else if (isInvoice || isPurchase) {
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
        pricesIncludeTax: business.pricesIncludeTax,
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

    // Determine status:
    // - Drafts only valid for invoice, quotation, and purchase.
    // - Receipts/expenses are always issued immediately.
    final String status;
    if (isDraft && (isInvoice || isQuotation || isPurchase)) {
      status = DocumentStatus.draft;
    } else if (isInvoice || isPurchase) {
      status = DocumentStatus.fromPayment(finalPaid, total);
    } else {
      status = DocumentStatus.issued;
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
      status: status,
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
      taxRate: item.taxRate,
    )).toList();

    final db = DatabaseHelper.instance;
    return db.insertDocumentWithItems(document, documentItems, contact: contact);
  }

  /// Updates an existing document.
  /// [isDraft] — if true, keeps the document as a draft. If false (default), the
  /// document is issued (or its payment status is recomputed from paid/total).
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
    bool isDraft = false,
  }) async {
    _validateBusiness(business);
    _validateTaxRate(business.taxRate);
    final db = DatabaseHelper.instance;
    final existing = await db.getDocumentById(documentId);
    if (existing == null) {
      throw ArgumentError('Document not found');
    }
    if (existing.status == DocumentStatus.cancelled) {
      throw StateError('Cannot edit a cancelled document');
    }

    final documentDate = date ?? existing.date;
    final isFinancial = type == 'payment_receipt' || type == 'expense_voucher';
    final isInvoice = type == 'invoice';
    final isPurchase = type == 'purchase';
    final isQuotation = type == 'quotation';
    final isCustom = type == 'custom';

    if (!isFinancial && !isCustom) {
      _validateItems(items);
      await _validateProductsExist(items);
    }

    if (isFinancial) {
      _validatePaymentMethod(paymentMethod);
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
      taxAmount = _calculateTaxMultiRate(
          items, discountApplied, taxRate, subtotal, business.pricesIncludeTax);
      total = business.pricesIncludeTax ? subtotal : subtotal + taxAmount;
      finalPaid = 0;
      remaining = total;
    } else if (isInvoice || isPurchase) {
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
        pricesIncludeTax: business.pricesIncludeTax,
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

    // Compute new status (same logic as createDocument)
    final String newStatus;
    if (isDraft && (isInvoice || isQuotation || isPurchase)) {
      newStatus = DocumentStatus.draft;
    } else if (isInvoice || isPurchase) {
      newStatus = DocumentStatus.fromPayment(finalPaid, total);
    } else {
      newStatus = DocumentStatus.issued;
    }

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
      status: newStatus,
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
      taxRate: item.taxRate,
    )).toList();

    await db.updateDocumentWithItems(updatedDocument, documentItems, contact: contact);
  }

  // ==================== Payment & Lifecycle ====================

  /// Records a payment and creates a linked payment_receipt document.
  /// Returns the new receipt document id.
  static Future<int> recordPayment({
    required int documentId,
    required double amount,
    String? paymentMethod,
    String? notes,
  }) async {
    if (amount <= 0) throw ArgumentError('Payment amount must be greater than zero');
    return DatabaseHelper.instance.recordPaymentWithReceipt(
      documentId: documentId,
      amount: amount,
      paymentMethod: paymentMethod,
      notes: notes,
    );
  }

  /// Marks a document as cancelled.
  /// For payment_receipts: also reverses the linked invoice payment transactionally.
  /// For non-draft invoices: stock is reverted.
  static Future<void> cancelDocument(int documentId) async {
    await DatabaseHelper.instance.cancelDocument(documentId);
    await DatabaseHelper.instance.logAuditEvent('document_cancelled',
        entityType: 'document', entityId: documentId);
  }

  /// Converts an issued (or draft) quotation to a new draft invoice.
  /// Returns the new invoice document id.
  static Future<int> convertQuotationToInvoice(int quotationId) async {
    return DatabaseHelper.instance.convertQuotationToInvoice(quotationId);
  }

  /// Promotes a draft document to issued, deducting stock for invoices.
  static Future<void> issueDocument(int documentId) async {
    await DatabaseHelper.instance.issueDocument(documentId);
    await DatabaseHelper.instance.logAuditEvent('document_issued',
        entityType: 'document', entityId: documentId);
  }

  /// Creates a new draft copy of an existing document.
  /// Returns the new document id.
  static Future<int> copyDocument(int documentId) async {
    return DatabaseHelper.instance.copyDocumentWithItems(documentId);
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

  static void _validatePaymentMethod(String? paymentMethod) {
    if (paymentMethod == null || paymentMethod.isEmpty) {
      throw ArgumentError('Invalid payment method');
    }
  }

  static double _calculateSubtotal(List<DocumentItemInput> items) {
    return items.fold<double>(0.0, (sum, item) => sum + item.total);
  }

  /// Calculates invoice totals supporting per-item tax rates and inclusive/exclusive modes.
  ///
  /// [taxRate] is the business-level fallback rate used when an item has no
  /// explicit [DocumentItemInput.taxRate] and is marked [taxable].
  ///
  /// [pricesIncludeTax] = true → inclusive mode: tax is embedded in the price,
  /// so total = subtotal − discount (tax is extracted for display only).
  /// [pricesIncludeTax] = false → exclusive mode: tax is added on top,
  /// so total = subtotal − discount + taxAmount.
  static ({double subtotal, double taxAmount, double total})
      calculateInvoiceTotals({
    required List<DocumentItemInput> items,
    required double discount,
    required double taxRate,
    bool pricesIncludeTax = false,
  }) {
    final subtotal = _calculateSubtotal(items);
    final taxAmount = _calculateTaxMultiRate(
        items, discount, taxRate, subtotal, pricesIncludeTax);
    final total = pricesIncludeTax
        ? subtotal - discount
        : subtotal - discount + taxAmount;
    return (subtotal: subtotal, taxAmount: taxAmount, total: total);
  }

  /// Per-item tax calculation with proportional discount and inclusive/exclusive support.
  static double _calculateTaxMultiRate(
    List<DocumentItemInput> items,
    double discount,
    double fallbackRate,
    double subtotal,
    bool pricesIncludeTax,
  ) {
    if (subtotal <= 0) return 0;
    final discountRatio = (subtotal - discount) / subtotal;
    var totalTax = 0.0;
    for (final item in items) {
      final rate = item.taxRate ?? (item.taxable ? fallbackRate : 0.0);
      if (rate <= 0) continue;
      final itemAfterDiscount = item.total * discountRatio;
      if (itemAfterDiscount <= 0) continue;
      totalTax += pricesIncludeTax
          ? itemAfterDiscount * rate / (100 + rate) // extract from inclusive price
          : itemAfterDiscount * rate / 100; // add on top (exclusive)
    }
    return totalTax < 0 ? 0 : totalTax;
  }

}
