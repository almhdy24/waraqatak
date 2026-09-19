import 'currency.dart';

class Business {
  final int? id;
  final String name;
  final String ownerName;
  final String phone;
  final String address;
  final String? email;
  final String? logoPath;
  final String currencyCode;
  final double taxRate;

  // Legal identity
  final String? legalName;
  final String? taxId;
  final String? taxReg;
  final String? commercialReg;
  final String? branch;

  // Tax configuration
  final bool taxesEnabled;
  final bool pricesIncludeTax;
  final int? defaultTaxProfileId;

  // Document settings
  final String? invoiceTitle;
  final String? legalFooter;

  const Business({
    this.id,
    required this.name,
    required this.ownerName,
    required this.phone,
    required this.address,
    this.email,
    this.logoPath,
    this.currencyCode = 'SDG',
    this.taxRate = 0,
    this.legalName,
    this.taxId,
    this.taxReg,
    this.commercialReg,
    this.branch,
    this.taxesEnabled = false,
    this.pricesIncludeTax = false,
    this.defaultTaxProfileId,
    this.invoiceTitle,
    this.legalFooter,
  });

  String get currencySymbol => Currency.symbolForCode(currencyCode);

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'owner_name': ownerName,
        'phone': phone,
        'address': address,
        'email': email,
        'logo_path': logoPath,
        'currency_code': currencyCode,
        'tax_rate': taxRate,
        'legal_name': legalName,
        'tax_id': taxId,
        'tax_reg': taxReg,
        'commercial_reg': commercialReg,
        'branch': branch,
        'taxes_enabled': taxesEnabled ? 1 : 0,
        'prices_include_tax': pricesIncludeTax ? 1 : 0,
        'default_tax_profile_id': defaultTaxProfileId,
        'invoice_title': invoiceTitle,
        'legal_footer': legalFooter,
      };

  factory Business.fromMap(Map<String, dynamic> map) => Business(
        id: map['id'] as int?,
        name: map['name'] as String,
        ownerName: map['owner_name'] as String,
        phone: map['phone'] as String,
        address: map['address'] as String,
        email: map['email'] as String?,
        logoPath: map['logo_path'] as String?,
        currencyCode: map['currency_code'] as String? ?? 'SDG',
        taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0,
        legalName: map['legal_name'] as String?,
        taxId: map['tax_id'] as String?,
        taxReg: map['tax_reg'] as String?,
        commercialReg: map['commercial_reg'] as String?,
        branch: map['branch'] as String?,
        taxesEnabled: (map['taxes_enabled'] as int? ?? 0) == 1,
        pricesIncludeTax: (map['prices_include_tax'] as int? ?? 0) == 1,
        defaultTaxProfileId: map['default_tax_profile_id'] as int?,
        invoiceTitle: map['invoice_title'] as String?,
        legalFooter: map['legal_footer'] as String?,
      );
}
