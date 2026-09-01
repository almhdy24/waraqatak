import 'currency.dart';

class Document {
  final int? id;
  final String type;
  final String documentNumber;
  final DateTime date;
  final int? contactId;
  final String? recipientName;
  final String? recipientPhone;
  final double subtotal;
  final double discount;
  final double taxRate;
  final double taxAmount;
  final double total;
  final double paid;
  final double remaining;
  final String? paymentMethod;
  final DateTime? validUntil;
  final String? notes;
  final int? relatedDocumentId;
  final String status;
  final String currencyCode;

  const Document({
    this.id,
    required this.type,
    required this.documentNumber,
    required this.date,
    this.contactId,
    this.recipientName,
    this.recipientPhone,
    required this.subtotal,
    required this.discount,
    required this.taxRate,
    required this.taxAmount,
    required this.total,
    required this.paid,
    required this.remaining,
    this.paymentMethod,
    this.validUntil,
    this.notes,
    this.relatedDocumentId,
    this.status = 'active',
    this.currencyCode = 'SDG',
  });

  String get currencySymbol => Currency.symbolForCode(currencyCode);

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'document_number': documentNumber,
        'date': date.toIso8601String(),
        'contact_id': contactId,
        'recipient_name': recipientName,
        'recipient_phone': recipientPhone,
        'subtotal': subtotal,
        'discount': discount,
        'tax_rate': taxRate,
        'tax_amount': taxAmount,
        'total': total,
        'paid': paid,
        'remaining': remaining,
        'payment_method': paymentMethod,
        'valid_until': validUntil?.toIso8601String(),
        'notes': notes,
        'related_document_id': relatedDocumentId,
        'status': status,
        'currency_code': currencyCode,
      };

  factory Document.fromMap(Map<String, dynamic> map) => Document(
        id: map['id'] as int?,
        type: map['type'] as String,
        documentNumber: map['document_number'] as String,
        date: DateTime.parse(map['date'] as String),
        contactId: map['contact_id'] as int?,
        recipientName: map['recipient_name'] as String?,
        recipientPhone: map['recipient_phone'] as String?,
        subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
        discount: (map['discount'] as num?)?.toDouble() ?? 0,
        taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0,
        taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0,
        total: (map['total'] as num?)?.toDouble() ?? 0,
        paid: (map['paid'] as num?)?.toDouble() ?? 0,
        remaining: (map['remaining'] as num?)?.toDouble() ?? 0,
        paymentMethod: map['payment_method'] as String?,
        validUntil: map['valid_until'] != null
            ? DateTime.parse(map['valid_until'] as String)
            : null,
        notes: map['notes'] as String?,
        relatedDocumentId: map['related_document_id'] as int?,
        status: map['status'] as String? ?? 'active',
        currencyCode: map['currency_code'] as String? ?? 'SDG',
      );
}