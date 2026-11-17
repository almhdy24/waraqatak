import '../database/database_helper.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/currency.dart';
import '../models/document.dart';
import '../models/document_item.dart';
import '../models/document_status.dart';
import '../models/product.dart';
import '../models/product_unit.dart';
import '../utils/money_utils.dart';
import 'access/access_guard.dart';
import 'access/permission_registry.dart';
import 'analytics/analytics_service.dart';
import 'feature_access.dart';
import 'license_service.dart';

class DocumentItemInput {
  final String description;
  final double quantity;
  final double price;
  final bool taxable;
  final int? productId;
  final double? taxRate; // per-item rate snapshot; null = use business default
  final String?
  pricingCategory; // 'retail' | 'wholesale' | null (legacy/manual)
  final String? saleUnit;
  final double unitConversionFactor;
  final double? baseQuantity;
  final int? decimalDigits;

  const DocumentItemInput({
    required this.description,
    required this.quantity,
    required this.price,
    this.taxable = true,
    this.productId,
    this.taxRate,
    this.pricingCategory,
    this.saleUnit,
    this.unitConversionFactor = 1.0,
    this.baseQuantity,
    this.decimalDigits,
  });

  double get effectiveBaseQuantity =>
      baseQuantity ?? MoneyUtils.round(quantity * unitConversionFactor);

  double calculateTotal([int? digits]) =>
      MoneyUtils.round(quantity * price, digits ?? decimalDigits ?? 2);

  double get total => calculateTotal();

  DocumentItemInput withDigits(int digits) {
    if (decimalDigits == digits) return this;
    return DocumentItemInput(
      description: description,
      quantity: quantity,
      price: price,
      taxable: taxable,
      productId: productId,
      taxRate: taxRate,
      pricingCategory: pricingCategory,
      saleUnit: saleUnit,
      unitConversionFactor: unitConversionFactor,
      baseQuantity: baseQuantity,
      decimalDigits: digits,
    );
  }
}

class DocumentService {
  /// Computes the whole calendar day difference between two dates safely in UTC,
  /// ignoring local time of day, timestamps, and timezone hour shifts.
  static int calendarDaysBetween(DateTime a, DateTime b) {
    final da = DateTime.utc(a.year, a.month, a.day);
    final db = DateTime.utc(b.year, b.month, b.day);
    return db.difference(da).inDays;
  }

  /// Creates a new document.
  /// [isDraft] — if true, the document is saved as a draft (invoice/quotation only);
  /// stock is not deducted and the document is excluded from financial summaries.
  static Future<int> createDocument({
    required String type,
    required Business business,
    Contact? contact,
    String? recipientName,
    String? recipientPhone,
    required List<DocumentItemInput> items,
    double discount = 0,
    double paid = 0,
    String? notes,
    int? relatedDocumentId,
    DateTime? date,
    DateTime? validUntil,
    String? paymentMethod,
    bool isDraft = false,
    String? payNowMethod,
    bool? strictStock,
  }) async {
    if (type == 'purchase') {
      AccessGuard.require(PermissionRegistry.purchasesCreate);
    } else if (type == 'payment_receipt' || type == 'expense_voucher') {
      AccessGuard.require(PermissionRegistry.vouchersCreate);
    } else {
      AccessGuard.require(PermissionRegistry.salesCreate);
    }

    if (discount > 0) {
      AccessGuard.require(PermissionRegistry.salesEditDiscount);
    }

    _validateBusiness(business);
    if (payNowMethod != null) {
      // Quick sale: the invoice is settled in full, in the same transaction,
      // through the regular payment path (linked receipt + payment row).
      if (type != 'invoice' || isDraft || paid != 0) {
        throw ArgumentError('payNowMethod requires a new, non-draft invoice');
      }
      _validatePaymentMethod(payNowMethod);
    }
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

    final decimalDigits = Currency.decimalDigitsForCode(business.currencyCode);
    final effectiveItems =
        ((!isFinancial && !isCustom)
                ? await resolveItemsTaxRates(items, business)
                : items)
            .map((i) => i.withDigits(decimalDigits))
            .toList();
    final effectiveTaxRate = await resolveEffectiveTaxRate(business);
    final effectivePricesIncludeTax =
        business.taxesEnabled && business.pricesIncludeTax;

    if (isFinancial) {
      final canonicalPaid = MoneyUtils.round(paid, decimalDigits);
      subtotal = canonicalPaid;
      finalPaid = canonicalPaid;
      remaining = 0;
      total = canonicalPaid;
    } else if (isQuotation) {
      if (validUntil == null) {
        throw ArgumentError('Valid until date is required for quotations');
      }
      final days = calendarDaysBetween(documentDate, validUntil);
      if (days == 0) {
        throw ArgumentError('Quotation validity period must be at least 1 day');
      }
      if (days < 0) {
        throw ArgumentError('Valid until must be after document date');
      }
      subtotal = MoneyUtils.round(
        _calculateSubtotal(effectiveItems),
        decimalDigits,
      );
      discountApplied = MoneyUtils.round(discount, decimalDigits);
      if (discountApplied < 0) {
        throw ArgumentError('Discount cannot be negative');
      }
      if (MoneyUtils.isOverpayment(discountApplied, subtotal, decimalDigits)) {
        throw ArgumentError('Discount cannot exceed subtotal');
      }
      final totals = calculateInvoiceTotals(
        items: effectiveItems,
        discount: discountApplied,
        taxRate: effectiveTaxRate,
        pricesIncludeTax: effectivePricesIncludeTax,
        decimalDigits: decimalDigits,
      );
      taxRate = effectiveTaxRate;
      taxAmount = totals.taxAmount;
      total = totals.total;
      finalPaid = 0;
      remaining = total;
    } else if (isInvoice || isPurchase) {
      subtotal = MoneyUtils.round(
        _calculateSubtotal(effectiveItems),
        decimalDigits,
      );
      discountApplied = MoneyUtils.round(discount, decimalDigits);
      if (discountApplied < 0) {
        throw ArgumentError('Discount cannot be negative');
      }
      if (MoneyUtils.isOverpayment(discountApplied, subtotal, decimalDigits)) {
        throw ArgumentError('Discount cannot exceed subtotal');
      }
      final totals = calculateInvoiceTotals(
        items: effectiveItems,
        discount: discountApplied,
        taxRate: effectiveTaxRate,
        pricesIncludeTax: effectivePricesIncludeTax,
        decimalDigits: decimalDigits,
      );
      taxRate = effectiveTaxRate;
      taxAmount = totals.taxAmount;
      total = totals.total;
      final canonicalPaid = MoneyUtils.round(paid, decimalDigits);
      if (canonicalPaid < 0) {
        throw ArgumentError('Paid amount cannot be negative');
      }
      if (MoneyUtils.isOverpayment(canonicalPaid, total, decimalDigits)) {
        throw ArgumentError('Paid amount cannot exceed total');
      }
      finalPaid = canonicalPaid;
      remaining = MoneyUtils.calculateRemaining(
        total,
        finalPaid,
        decimalDigits,
      );
    } else if (isCustom) {
      final canonicalPaid = MoneyUtils.round(paid, decimalDigits);
      subtotal = canonicalPaid;
      total = canonicalPaid;
      finalPaid = canonicalPaid;
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
      status = DocumentStatus.fromPayment(
        finalPaid,
        total,
        decimalDigits: decimalDigits,
      );
    } else {
      status = DocumentStatus.issued;
    }

    final document = Document(
      type: type,
      documentNumber: '',
      date: documentDate,
      contactId: contact?.id,
      recipientName: recipientName ?? contact?.name,
      recipientPhone: recipientPhone ?? contact?.phone,
      subtotal: subtotal,
      discount: discountApplied,
      taxRate: isFinancial || isCustom ? 0 : taxRate,
      taxAmount: isFinancial || isCustom ? 0 : taxAmount,
      total: total,
      paid: finalPaid,
      remaining: remaining,
      paymentMethod: paymentMethod,
      validUntil: isQuotation ? validUntil : null,
      notes: notes,
      relatedDocumentId: relatedDocumentId,
      status: status,
      currencyCode: business.currencyCode,
    );

    final documentItems = effectiveItems
        .map(
          (item) => DocumentItem(
            documentId: 0,
            productId: item.productId,
            description: item.description,
            quantity: item.quantity,
            price: item.price,
            total: item.total,
            taxable: item.taxable,
            taxRate: item.taxRate,
            pricingCategory: item.pricingCategory,
            saleUnit: item.saleUnit,
            unitConversionFactor: item.unitConversionFactor,
            baseQuantity: item.effectiveBaseQuantity,
          ),
        )
        .toList();

    final bool enforceStock;
    if (strictStock != null) {
      enforceStock = strictStock;
    } else {
      final entitlement = await LicenseService.instance.checkEntitlement();
      enforceStock = FeatureAccess.canAccess(Feature.inventory, entitlement);
    }

    final db = DatabaseHelper.instance;
    final docId = await db.insertDocumentWithItems(
      document,
      documentItems,
      contact: contact,
      payNowMethod: payNowMethod,
      strictStock: enforceStock,
    );

    try {
      AnalyticsService.instance.track(AnalyticsEvent.documentCreated, {
        'type': _canonicalDocType(type),
        'has_payment': finalPaid > 0 || payNowMethod != null,
        'item_count_bucket': AnalyticsService.itemCountBucket(
          effectiveItems.length,
        ),
      });
    } catch (_) {}

    return docId;
  }

  /// Updates an existing document.
  /// [isDraft] — if true, keeps the document as a draft. If false (default), the
  /// document is issued (or its payment status is recomputed from paid/total).
  static Future<void> updateDocument({
    required int documentId,
    required String type,
    required Business business,
    Contact? contact,
    String? recipientName,
    String? recipientPhone,
    required List<DocumentItemInput> items,
    double discount = 0,
    double paid = 0,
    String? notes,
    int? relatedDocumentId,
    DateTime? date,
    DateTime? validUntil,
    String? paymentMethod,
    bool isDraft = false,
    String? payNowMethod,
    bool? strictStock,
  }) async {
    if (type == 'purchase') {
      AccessGuard.require(PermissionRegistry.purchasesEdit);
    } else {
      AccessGuard.require(PermissionRegistry.salesEdit);
    }

    if (discount > 0) {
      AccessGuard.require(PermissionRegistry.salesEditDiscount);
    }

    _validateBusiness(business);
    if (payNowMethod != null) {
      throw ArgumentError('payNowMethod is not supported when updating');
    }
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

    final decimalDigits = Currency.decimalDigitsForCode(existing.currencyCode);
    final effectiveItems =
        ((!isFinancial && !isCustom)
                ? await resolveItemsTaxRates(items, business)
                : items)
            .map((i) => i.withDigits(decimalDigits))
            .toList();
    final effectiveTaxRate = await resolveEffectiveTaxRate(business);
    final effectivePricesIncludeTax =
        business.taxesEnabled && business.pricesIncludeTax;

    if (isFinancial) {
      final canonicalPaid = MoneyUtils.round(paid, decimalDigits);
      subtotal = canonicalPaid;
      finalPaid = canonicalPaid;
      remaining = 0;
      total = canonicalPaid;
    } else if (isQuotation) {
      if (validUntil == null) {
        throw ArgumentError('Valid until date is required for quotations');
      }
      final days = calendarDaysBetween(documentDate, validUntil);
      if (days == 0) {
        throw ArgumentError('Quotation validity period must be at least 1 day');
      }
      if (days < 0) {
        throw ArgumentError('Valid until must be after document date');
      }
      subtotal = MoneyUtils.round(
        _calculateSubtotal(effectiveItems),
        decimalDigits,
      );
      discountApplied = MoneyUtils.round(discount, decimalDigits);
      if (discountApplied < 0) {
        throw ArgumentError('Discount cannot be negative');
      }
      if (MoneyUtils.isOverpayment(discountApplied, subtotal, decimalDigits)) {
        throw ArgumentError('Discount cannot exceed subtotal');
      }
      final totals = calculateInvoiceTotals(
        items: effectiveItems,
        discount: discountApplied,
        taxRate: effectiveTaxRate,
        pricesIncludeTax: effectivePricesIncludeTax,
        decimalDigits: decimalDigits,
      );
      taxRate = effectiveTaxRate;
      taxAmount = totals.taxAmount;
      total = totals.total;
      finalPaid = 0;
      remaining = total;
    } else if (isInvoice || isPurchase) {
      subtotal = MoneyUtils.round(
        _calculateSubtotal(effectiveItems),
        decimalDigits,
      );
      discountApplied = MoneyUtils.round(discount, decimalDigits);
      if (discountApplied < 0) {
        throw ArgumentError('Discount cannot be negative');
      }
      if (MoneyUtils.isOverpayment(discountApplied, subtotal, decimalDigits)) {
        throw ArgumentError('Discount cannot exceed subtotal');
      }
      final totals = calculateInvoiceTotals(
        items: effectiveItems,
        discount: discountApplied,
        taxRate: effectiveTaxRate,
        pricesIncludeTax: effectivePricesIncludeTax,
        decimalDigits: decimalDigits,
      );
      taxRate = effectiveTaxRate;
      taxAmount = totals.taxAmount;
      total = totals.total;
      final canonicalPaid = MoneyUtils.round(paid, decimalDigits);
      if (canonicalPaid < 0) {
        throw ArgumentError('Paid amount cannot be negative');
      }
      if (MoneyUtils.isOverpayment(canonicalPaid, total, decimalDigits)) {
        throw ArgumentError('Paid amount cannot exceed total');
      }
      finalPaid = canonicalPaid;
      remaining = MoneyUtils.calculateRemaining(
        total,
        finalPaid,
        decimalDigits,
      );
    } else if (isCustom) {
      final canonicalPaid = MoneyUtils.round(paid, decimalDigits);
      subtotal = canonicalPaid;
      total = canonicalPaid;
      finalPaid = canonicalPaid;
      remaining = 0;
    } else {
      throw ArgumentError('Unknown document type: $type');
    }

    final effectiveRelatedDocumentId =
        relatedDocumentId ?? existing.relatedDocumentId;

    // Compute new status (same logic as createDocument)
    final String newStatus;
    if (isDraft && (isInvoice || isQuotation || isPurchase)) {
      newStatus = DocumentStatus.draft;
    } else if (isInvoice || isPurchase) {
      newStatus = DocumentStatus.fromPayment(
        finalPaid,
        total,
        decimalDigits: decimalDigits,
      );
    } else {
      newStatus = DocumentStatus.issued;
    }

    final updatedDocument = Document(
      id: documentId,
      type: type,
      documentNumber: existing.documentNumber,
      date: documentDate,
      contactId: contact?.id,
      recipientName: recipientName ??
          (contact != null ? contact.name : existing.recipientName),
      recipientPhone: recipientPhone ??
          (contact != null ? contact.phone : existing.recipientPhone),
      subtotal: subtotal,
      discount: discountApplied,
      taxRate: isFinancial || isCustom ? 0 : taxRate,
      taxAmount: isFinancial || isCustom ? 0 : taxAmount,
      total: total,
      paid: finalPaid,
      remaining: remaining,
      paymentMethod: paymentMethod,
      validUntil: isQuotation ? validUntil : null,
      notes: notes,
      relatedDocumentId: effectiveRelatedDocumentId,
      status: newStatus,
      currencyCode: existing.currencyCode,
    );

    final documentItems = effectiveItems
        .map(
          (item) => DocumentItem(
            documentId: documentId,
            productId: item.productId,
            description: item.description,
            quantity: item.quantity,
            price: item.price,
            total: item.total,
            taxable: item.taxable,
            taxRate: item.taxRate,
            pricingCategory: item.pricingCategory,
            saleUnit: item.saleUnit,
            unitConversionFactor: item.unitConversionFactor,
            baseQuantity: item.effectiveBaseQuantity,
          ),
        )
        .toList();

    final bool enforceStock;
    if (strictStock != null) {
      enforceStock = strictStock;
    } else {
      final entitlement = await LicenseService.instance.checkEntitlement();
      enforceStock = FeatureAccess.canAccess(Feature.inventory, entitlement);
    }

    await db.updateDocumentWithItems(
      updatedDocument,
      documentItems,
      contact: contact,
      strictStock: enforceStock,
    );
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
    AccessGuard.require(PermissionRegistry.paymentsRecord);
    if (amount <= 0) {
      throw ArgumentError('Payment amount must be greater than zero');
    }
    final receiptId = await DatabaseHelper.instance.recordPaymentWithReceipt(
      documentId: documentId,
      amount: amount,
      paymentMethod: paymentMethod,
      notes: notes,
    );

    try {
      AnalyticsService.instance.track(AnalyticsEvent.paymentRecorded, {
        'method_category': _categorizePaymentMethod(paymentMethod),
      });
    } catch (_) {}

    return receiptId;
  }

  /// Records payment allocated across open documents for [contactId] using FIFO.
  /// Validates [amount] > 0, delegates to [DatabaseHelper.recordFifoPayment],
  /// logs audit event, and returns receipt IDs.
  static Future<List<int>> recordFifoPayment({
    required int contactId,
    required bool isCustomer,
    required double amount,
    String? paymentMethod,
    String? notes,
  }) async {
    AccessGuard.require(PermissionRegistry.paymentsRecord);
    if (amount <= 0) {
      throw ArgumentError('Payment amount must be greater than zero');
    }
    final docType = isCustomer ? 'invoice' : 'purchase';
    final receiptIds = await DatabaseHelper.instance.recordFifoPayment(
      contactId: contactId,
      documentType: docType,
      amount: amount,
      paymentMethod: paymentMethod,
      notes: notes,
    );
    await DatabaseHelper.instance.logAuditEvent(
      'payment_allocated',
      entityType: 'contact',
      entityId: contactId,
      details:
          'amount=$amount docType=$docType receipts=${receiptIds.join(",")}',
    );

    try {
      AnalyticsService.instance.track(AnalyticsEvent.paymentRecorded, {
        'method_category': _categorizePaymentMethod(paymentMethod),
      });
    } catch (_) {}

    return receiptIds;
  }

  /// Marks a document as cancelled.
  /// For payment_receipts: also reverses the linked invoice payment transactionally.
  /// For non-draft invoices: stock is reverted.
  static Future<void> cancelDocument(
    int documentId, {
    String? refundStatus,
    String? refundNotes,
  }) async {
    final doc = await DatabaseHelper.instance.getDocumentById(documentId);
    await DatabaseHelper.instance.cancelDocument(
      documentId,
      refundStatus: refundStatus,
      refundNotes: refundNotes,
    );
    await DatabaseHelper.instance.logAuditEvent(
      'document_cancelled',
      entityType: 'document',
      entityId: documentId,
    );

    try {
      AnalyticsService.instance.track(AnalyticsEvent.documentCancelled, {
        'type': _canonicalDocType(doc?.type ?? 'invoice'),
      });
    } catch (_) {}
  }

  /// Updates or records the refund status for a cancelled document.
  static Future<void> updateDocumentRefundStatus({
    required int documentId,
    required String status,
    String? notes,
  }) async {
    await DatabaseHelper.instance.updateDocumentRefundStatus(
      documentId: documentId,
      status: status,
      notes: notes,
    );
  }

  /// Returns the latest recorded refund status for a document, if any.
  static Future<Map<String, dynamic>?> getLatestDocumentRefundStatus(
    int documentId,
  ) async {
    return DatabaseHelper.instance.getLatestDocumentRefundStatus(documentId);
  }

  /// Converts an issued (or draft) quotation to a new draft invoice.
  /// Returns the new invoice document id.
  static Future<int> convertQuotationToInvoice(int quotationId) async {
    return DatabaseHelper.instance.convertQuotationToInvoice(quotationId);
  }

  /// Promotes a draft document to issued, deducting stock for invoices.
  static Future<void> issueDocument(int documentId, {bool? strictStock}) async {
    final doc = await DatabaseHelper.instance.getDocumentById(documentId);
    if (doc == null) throw StateError('Document not found');
    if (doc.status != DocumentStatus.draft) {
      throw StateError('Document is not a draft');
    }

    if (doc.type == 'purchase') {
      AccessGuard.require(PermissionRegistry.purchasesCreate);
    } else if (doc.type == 'payment_receipt' || doc.type == 'expense_voucher') {
      AccessGuard.require(PermissionRegistry.vouchersCreate);
    } else {
      AccessGuard.require(PermissionRegistry.salesCreate);
    }

    if (doc.paid > 0 && (doc.type == 'invoice' || doc.type == 'purchase')) {
      AccessGuard.require(PermissionRegistry.paymentsRecord);
    }

    final bool enforceStock;
    if (strictStock != null) {
      enforceStock = strictStock;
    } else {
      final entitlement = await LicenseService.instance.checkEntitlement();
      enforceStock = FeatureAccess.canAccess(Feature.inventory, entitlement);
    }
    await DatabaseHelper.instance.issueDocument(
      documentId,
      strictStock: enforceStock,
    );
    await DatabaseHelper.instance.logAuditEvent(
      'document_issued',
      entityType: 'document',
      entityId: documentId,
    );
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

  static Future<void> _validateProductsExist(
    List<DocumentItemInput> items,
  ) async {
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

  /// Resolves the effective business default tax rate:
  /// - If [business.taxesEnabled] is false -> always 0.0.
  /// - If [business.taxesEnabled] is true:
  ///   - If [business.defaultTaxProfileId] is set, lookup profile rate if active.
  ///   - Otherwise falls back to [business.taxRate].
  static Future<double> resolveEffectiveTaxRate(
    Business business, {
    DatabaseHelper? db,
  }) async {
    if (!business.taxesEnabled) return 0.0;
    final database = db ?? DatabaseHelper.instance;
    if (business.defaultTaxProfileId != null) {
      final profile = await database.getTaxProfileById(
        business.defaultTaxProfileId!,
      );
      if (profile != null && profile.isActive) {
        return profile.rate;
      }
    }
    return business.taxRate;
  }

  /// Resolves line items' tax rates and taxable status from their linked products
  /// and tax profiles when not explicitly provided.
  /// - If [business.taxesEnabled] is false, all items are treated as 0% tax.
  /// - If an item is linked to a product:
  ///   - If the product is not taxable, [taxable] becomes false, and [taxRate] is 0.0.
  ///   - If the product has a linked active tax profile, [taxRate] is set to the profile's rate.
  ///   - If the product has a 0% tax profile, [taxRate] is set to 0.0 (zero-rated).
  static Future<List<DocumentItemInput>> resolveItemsTaxRates(
    List<DocumentItemInput> items,
    Business business, {
    DatabaseHelper? db,
  }) async {
    if (!business.taxesEnabled) {
      return items
          .map(
            (item) => DocumentItemInput(
              description: item.description,
              quantity: item.quantity,
              price: item.price,
              taxable: false,
              productId: item.productId,
              taxRate: 0.0,
              pricingCategory: item.pricingCategory,
              saleUnit: item.saleUnit,
              unitConversionFactor: item.unitConversionFactor,
              baseQuantity: item.baseQuantity,
              decimalDigits: item.decimalDigits,
            ),
          )
          .toList();
    }

    final database = db ?? DatabaseHelper.instance;
    final resolved = <DocumentItemInput>[];

    for (final item in items) {
      if (item.taxRate != null) {
        // Explicit per-item rate already provided
        resolved.add(item);
        continue;
      }

      if (item.productId != null) {
        final product = await database.getProductById(item.productId!);
        if (product != null) {
          if (!product.isTaxable) {
            resolved.add(
              DocumentItemInput(
                description: item.description,
                quantity: item.quantity,
                price: item.price,
                taxable: false,
                productId: item.productId,
                taxRate: 0.0,
                pricingCategory: item.pricingCategory,
                saleUnit: item.saleUnit,
                unitConversionFactor: item.unitConversionFactor,
                baseQuantity: item.baseQuantity,
                decimalDigits: item.decimalDigits,
              ),
            );
            continue;
          }

          if (product.taxProfileId != null) {
            final profile = await database.getTaxProfileById(
              product.taxProfileId!,
            );
            if (profile != null && profile.isActive) {
              resolved.add(
                DocumentItemInput(
                  description: item.description,
                  quantity: item.quantity,
                  price: item.price,
                  taxable: true,
                  productId: item.productId,
                  taxRate: profile.rate,
                  pricingCategory: item.pricingCategory,
                  saleUnit: item.saleUnit,
                  unitConversionFactor: item.unitConversionFactor,
                  baseQuantity: item.baseQuantity,
                  decimalDigits: item.decimalDigits,
                ),
              );
              continue;
            }
          }
        }
      }

      // No explicit product profile; keep item with null taxRate (will use business fallback)
      resolved.add(item);
    }

    return resolved;
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
  ///
  /// [decimalDigits] defines the currency's canonical rounding scale (default: 2).
  static ({double subtotal, double taxAmount, double total})
  calculateInvoiceTotals({
    required List<DocumentItemInput> items,
    required double discount,
    required double taxRate,
    bool pricesIncludeTax = false,
    int decimalDigits = 2,
  }) {
    final normalized = items.map((i) => i.withDigits(decimalDigits)).toList();
    final subtotal = MoneyUtils.round(
      _calculateSubtotal(normalized),
      decimalDigits,
    );
    final canonicalDiscount = MoneyUtils.round(discount, decimalDigits);
    final taxAmount = _calculateTaxMultiRate(
      normalized,
      canonicalDiscount,
      taxRate,
      subtotal,
      pricesIncludeTax,
      decimalDigits: decimalDigits,
    );
    final total = pricesIncludeTax
        ? MoneyUtils.round(subtotal - canonicalDiscount, decimalDigits)
        : MoneyUtils.round(
            subtotal - canonicalDiscount + taxAmount,
            decimalDigits,
          );
    return (subtotal: subtotal, taxAmount: taxAmount, total: total);
  }

  /// Per-item tax calculation with proportional discount and inclusive/exclusive support.
  static double _calculateTaxMultiRate(
    List<DocumentItemInput> items,
    double discount,
    double fallbackRate,
    double subtotal,
    bool pricesIncludeTax, {
    int decimalDigits = 2,
  }) {
    if (subtotal <= 0) return 0;
    final discountRatio = (subtotal - discount) / subtotal;
    var totalTax = 0.0;
    for (final item in items) {
      final rate = item.taxRate ?? (item.taxable ? fallbackRate : 0.0);
      if (rate <= 0) continue;
      final itemAfterDiscount = item.total * discountRatio;
      if (itemAfterDiscount <= 0) continue;
      totalTax += pricesIncludeTax
          ? itemAfterDiscount *
                rate /
                (100 + rate) // extract from inclusive price
          : itemAfterDiscount * rate / 100; // add on top (exclusive)
    }
    return MoneyUtils.round(totalTax < 0 ? 0.0 : totalTax, decimalDigits);
  }

  /// Resolves the unit selling price for [product] given the requested [targetCategory],
  /// line [quantity], and optional [unit] conversion factor, respecting the business
  /// [wholesalePricingEnabled] toggle.
  ///
  /// Rules:
  /// 1. If [unit] is provided with [conversionFactor] > 0:
  ///    - Effective retail price is [unit.salePrice] or [product.salePrice * factor].
  ///    - Effective wholesale candidate is [unit.wholesalePrice] or ([product.wholesalePrice * factor] if configured).
  ///    - Minimum wholesale quantity is evaluated in base units: ([quantity * factor] >= minBaseQty).
  /// 2. If [wholesalePricingEnabled] is false, always returns effective retail price.
  /// 3. If [targetCategory] is 'wholesale':
  ///    - If candidate wholesale price is available and base quantity meets minimum, applies wholesale price.
  ///    - Otherwise falls back safely to effective retail price.
  /// 4. Otherwise returns effective retail price.
  static double resolveItemPrice({
    required Product product,
    required String? targetCategory,
    required double quantity,
    required bool wholesalePricingEnabled,
    ProductUnit? unit,
  }) {
    final factor = (unit != null && unit.conversionFactor > 0)
        ? unit.conversionFactor
        : 1.0;
    final baseQty = quantity * factor;

    final double effectiveRetailPrice = (unit?.salePrice != null)
        ? unit!.salePrice!
        : product.salePrice * factor;

    if (!wholesalePricingEnabled) {
      return effectiveRetailPrice;
    }

    if (targetCategory == 'wholesale') {
      final double? candidateWholesalePrice;
      if (unit?.wholesalePrice != null) {
        candidateWholesalePrice = unit!.wholesalePrice;
      } else if (product.wholesalePrice != null) {
        candidateWholesalePrice = product.wholesalePrice! * factor;
      } else {
        candidateWholesalePrice = null;
      }

      if (candidateWholesalePrice != null) {
        final minBaseQty = product.wholesaleMinQuantity;
        if (minBaseQty == null || baseQty >= minBaseQty) {
          return candidateWholesalePrice;
        }
      }
      return effectiveRetailPrice;
    }

    return effectiveRetailPrice;
  }

  /// Authoritative single entry point for line-level repricing across all document screens.
  ///
  /// Takes the full line state (product, current price, saleUnit, unitConversionFactor,
  /// current pricingCategory, manual override flag) along with [availableUnits] and [targetCategory].
  ///
  /// Rules:
  /// 1. Manual price overrides ([isManualPrice] == true) are NEVER overwritten.
  /// 2. Legacy lines with null [pricingCategory] and an existing [currentPrice] are NEVER overwritten.
  /// 3. If [saleUnit] is specified but does not match any unit in [availableUnits] (or product base unit),
  ///    history wins and [currentPrice] is preserved.
  /// 4. If the line's snapshot [unitConversionFactor] differs from the current unit's conversion factor,
  ///    history wins and [currentPrice] is preserved.
  /// 5. Otherwise, resolves price with the matching [ProductUnit] and [targetCategory] via [resolveItemPrice].
  static double resolveLinePrice({
    required Product product,
    Iterable<ProductUnit> availableUnits = const [],
    required double quantity,
    double? currentPrice,
    String? saleUnit,
    double? unitConversionFactor,
    String? pricingCategory,
    required String? targetCategory,
    bool isManualPrice = false,
    bool wholesalePricingEnabled = false,
    ProductUnit? unit,
  }) {
    if (isManualPrice && currentPrice != null) {
      AccessGuard.require(
        PermissionRegistry.salesEditPrice,
        'Manual price override requires sales.edit_price permission',
      );
      return currentPrice;
    }
    if (pricingCategory == null && currentPrice != null) {
      return currentPrice;
    }

    ProductUnit? matchingUnit = unit;
    if (matchingUnit == null) {
      final isBaseUnit =
          saleUnit == null ||
          saleUnit.trim().isEmpty ||
          saleUnit.trim() == product.unit?.trim();

      if (isBaseUnit) {
        if (unitConversionFactor != null &&
            (unitConversionFactor - 1.0).abs() > 0.0001) {
          // Base unit factor mismatch with history
          if (currentPrice != null) return currentPrice;
        }
        matchingUnit = null;
      } else {
        ProductUnit? found;
        for (final u in availableUnits) {
          if (u.unitName.trim() == saleUnit.trim()) {
            found = u;
            break;
          }
        }
        if (found == null) {
          // Unit no longer exists; preserve historical price
          if (currentPrice != null) return currentPrice;
        } else {
          if (unitConversionFactor != null &&
              (unitConversionFactor - found.conversionFactor).abs() > 0.0001) {
            // Unit conversion factor changed since document line was created; preserve historical price
            if (currentPrice != null) return currentPrice;
          }
          matchingUnit = found;
        }
      }
    } else {
      if (unitConversionFactor != null &&
          (unitConversionFactor - matchingUnit.conversionFactor).abs() >
              0.0001) {
        if (currentPrice != null) return currentPrice;
      }
    }

    return resolveItemPrice(
      product: product,
      targetCategory: targetCategory,
      quantity: quantity,
      wholesalePricingEnabled: wholesalePricingEnabled,
      unit: matchingUnit,
    );
  }

  static String _canonicalDocType(String type) {
    if (type == 'payment_receipt') return 'receipt';
    if (type == 'expense_voucher') return 'expense';
    if (const {'invoice', 'purchase', 'quotation', 'custom'}.contains(type)) {
      return type;
    }
    return 'custom';
  }

  static String _categorizePaymentMethod(String? method) {
    if (method == null) return 'other';
    final lower = method.toLowerCase().trim();
    if (lower.contains('cash') ||
        lower.contains('نقد') ||
        lower.contains('كاش')) {
      return 'cash';
    }
    if (lower.contains('bank') ||
        lower.contains('بنك') ||
        lower.contains('تحويل') ||
        lower.contains('شيك') ||
        lower.contains('card') ||
        lower.contains('بطاق')) {
      return 'bank';
    }
    if (lower.contains('mobile') ||
        lower.contains('محفظ') ||
        lower.contains('pay') ||
        lower.contains('insta') ||
        lower.contains('فودافون')) {
      return 'mobile';
    }
    return 'other';
  }
}
