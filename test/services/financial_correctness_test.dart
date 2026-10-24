import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/payment_method.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/services/business_reporting_service.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/services/pos_cart.dart';
import 'package:warqatek/utils/currency_utils.dart';
import 'package:warqatek/utils/format_utils.dart';

void main() {
  group('1. Taxes disabled while legacy tax rate is nonzero', () {
    const businessWithDisabledTaxes = Business(
      id: 1,
      name: 'Test Store',
      ownerName: 'Merchant',
      phone: '123456',
      address: 'Test City',
      taxRate: 15.0, // Legacy nonzero rate stored in DB
      taxesEnabled: false, // User explicitly turned off taxes
    );

    test('effectiveTaxRate returns 0.0 when taxesEnabled is false', () {
      expect(businessWithDisabledTaxes.effectiveTaxRate, 0.0);
    });

    test(
      'resolveEffectiveTaxRate returns 0.0 regardless of business.taxRate',
      () async {
        final rate = await DocumentService.resolveEffectiveTaxRate(
          businessWithDisabledTaxes,
        );
        expect(rate, 0.0);
      },
    );

    test(
      'resolveItemsTaxRates disables tax on all items when taxesEnabled is false',
      () async {
        const items = [
          DocumentItemInput(description: 'Item 1', quantity: 2, price: 50.0),
          DocumentItemInput(
            description: 'Item 2',
            quantity: 1,
            price: 100.0,
            taxRate: 15.0,
          ),
        ];
        final resolved = await DocumentService.resolveItemsTaxRates(
          items,
          businessWithDisabledTaxes,
        );
        for (final item in resolved) {
          expect(item.taxRate, 0.0);
          expect(item.taxable, isFalse);
        }
      },
    );

    test(
      'calculateInvoiceTotals calculates zero tax when taxes are disabled',
      () {
        const items = [
          DocumentItemInput(description: 'Item', quantity: 2, price: 100.0),
        ];
        final totals = DocumentService.calculateInvoiceTotals(
          items: items,
          discount: 20.0,
          taxRate: businessWithDisabledTaxes.effectiveTaxRate,
        );
        expect(totals.subtotal, 200.0);
        expect(totals.taxAmount, 0.0);
        expect(totals.total, 180.0);
      },
    );
  });

  group('2. Enabled taxes and default tax profiles', () {
    const businessWithEnabledTaxes = Business(
      id: 1,
      name: 'Test Store',
      ownerName: 'Merchant',
      phone: '123456',
      address: 'Test City',
      taxRate: 15.0,
      taxesEnabled: true,
    );

    test('effectiveTaxRate returns business taxRate when enabled', () {
      expect(businessWithEnabledTaxes.effectiveTaxRate, 15.0);
    });

    test(
      'calculateInvoiceTotals applies default rate to standard taxable items',
      () {
        const items = [
          DocumentItemInput(description: 'Item A', quantity: 1, price: 100.0),
        ];
        final totals = DocumentService.calculateInvoiceTotals(
          items: items,
          discount: 0.0,
          taxRate: businessWithEnabledTaxes.effectiveTaxRate,
        );
        expect(totals.subtotal, 100.0);
        expect(totals.taxAmount, 15.0);
        expect(totals.total, 115.0);
      },
    );
  });

  group('3. Product-level reduced and zero-rated tax profiles', () {
    test(
      'Zero-rated item (explicit 0% taxRate) does not fall back to standard rate',
      () {
        const items = [
          DocumentItemInput(
            description: 'Zero-rated bread',
            quantity: 2,
            price: 50.0,
            taxRate: 0.0, // Explicitly zero-rated via TaxProfile(rate: 0)
            taxable: true,
          ),
        ];
        final totals = DocumentService.calculateInvoiceTotals(
          items: items,
          discount: 0.0,
          taxRate: 15.0, // Business fallback is 15%
        );
        expect(totals.subtotal, 100.0);
        expect(totals.taxAmount, 0.0);
        expect(totals.total, 100.0);
      },
    );

    test(
      'Reduced rate item (5%) correctly overrides business standard rate (15%)',
      () {
        const items = [
          DocumentItemInput(
            description: 'Standard product',
            quantity: 1,
            price: 100.0,
            taxRate: null, // Uses business fallback (15%)
            taxable: true,
          ),
          DocumentItemInput(
            description: 'Reduced medicine',
            quantity: 1,
            price: 100.0,
            taxRate: 5.0, // Reduced rate profile
            taxable: true,
          ),
          DocumentItemInput(
            description: 'Exempt service',
            quantity: 1,
            price: 100.0,
            taxable: false, // Exempt
          ),
        ];
        final totals = DocumentService.calculateInvoiceTotals(
          items: items,
          discount: 0.0,
          taxRate: 15.0,
        );
        // Item 1 tax: 100 * 15% = 15.0
        // Item 2 tax: 100 * 5% = 5.0
        // Item 3 tax: 0
        // Total tax: 20.0
        expect(totals.subtotal, 300.0);
        expect(totals.taxAmount, 20.0);
        expect(totals.total, 320.0);
      },
    );
  });

  group('4. Inclusive vs exclusive tax, decimal rates, and rounding', () {
    test('Decimal tax rate 15.5% precision on exclusive invoice', () {
      const items = [
        DocumentItemInput(description: 'Item', quantity: 1, price: 100.0),
      ];
      final totals = DocumentService.calculateInvoiceTotals(
        items: items,
        discount: 0.0,
        taxRate: 15.5,
      );
      expect(totals.subtotal, 100.0);
      expect(totals.taxAmount, 15.50);
      expect(totals.total, 115.50);
    });

    test('Decimal tax rate 5.25% precision with discount', () {
      const items = [
        DocumentItemInput(description: 'Item', quantity: 1, price: 200.0),
      ];
      final totals = DocumentService.calculateInvoiceTotals(
        items: items,
        discount: 20.0, // Net base = 180.0
        taxRate: 5.25,
      );
      // Tax: 180 * 5.25% = 9.45
      expect(totals.taxAmount, 9.45);
      expect(totals.total, 189.45);
    });

    test('Inclusive tax extraction at 15.5% rate', () {
      const items = [
        DocumentItemInput(description: 'Item', quantity: 1, price: 115.50),
      ];
      final totals = DocumentService.calculateInvoiceTotals(
        items: items,
        discount: 0.0,
        taxRate: 15.5,
        pricesIncludeTax: true,
      );
      // Tax extracted: 115.50 * 15.5 / (100 + 15.5) = 115.50 * 15.5 / 115.5 = 15.50
      expect(totals.subtotal, 115.50);
      expect(totals.taxAmount, 15.50);
      expect(totals.total, 115.50);
    });

    test(
      'FormatUtils.formatTaxRate preserves decimals and avoids truncation',
      () {
        expect(FormatUtils.formatTaxRate(15.0), '15%');
        expect(FormatUtils.formatTaxRate(15.5), '15.5%');
        expect(FormatUtils.formatTaxRate(5.25), '5.25%');
        expect(FormatUtils.formatTaxRate(0.0), '0%');
      },
    );
  });

  group('5. Historical document safety and inclusive tax detection', () {
    test(
      'Inclusive tax invariant detection from authoritative stored numbers',
      () {
        // Inclusive document: total = subtotal - discount, with taxAmount > 0
        final inclusiveDoc = Document(
          id: 1,
          type: 'invoice',
          documentNumber: 'INV-001',
          date: DateTime.now(),
          subtotal: 115.0,
          discount: 0.0,
          taxRate: 15.0,
          taxAmount: 15.0,
          total: 115.0,
          paid: 0.0,
          remaining: 115.0,
        );
        final isInclusive =
            (inclusiveDoc.subtotal - inclusiveDoc.discount - inclusiveDoc.total)
                    .abs() <
                0.01 &&
            inclusiveDoc.taxAmount > 0;
        expect(isInclusive, isTrue);

        // Exclusive document: subtotal - discount + taxAmount == total
        final exclusiveDoc = Document(
          id: 2,
          type: 'invoice',
          documentNumber: 'INV-002',
          date: DateTime.now(),
          subtotal: 100.0,
          discount: 0.0,
          taxRate: 15.0,
          taxAmount: 15.0,
          total: 115.0,
          paid: 0.0,
          remaining: 115.0,
        );
        final isExclusiveInclusiveCheck =
            (exclusiveDoc.subtotal - exclusiveDoc.discount - exclusiveDoc.total)
                    .abs() <
                0.01 &&
            exclusiveDoc.taxAmount > 0;
        expect(isExclusiveInclusiveCheck, isFalse);
      },
    );
  });

  group('6. Custom payment method label resolution', () {
    final l10nAr = AppLocalizations('ar');
    final l10nEn = AppLocalizations('en');

    test('Predefined methods resolve localized names', () {
      expect(CurrencyUtils.getPaymentMethodLabel('cash', l10nAr), 'نقداً');
      expect(CurrencyUtils.getPaymentMethodLabel('cash', l10nEn), 'Cash');
      expect(CurrencyUtils.getPaymentMethodLabel('bank', l10nAr), 'تحويل بنكي');
      expect(
        CurrencyUtils.getPaymentMethodLabel('bank', l10nEn),
        'Bank Transfer',
      );
    });

    test('Custom methods with custom labels resolve in Arabic and English', () {
      const customKey = 'custom_1729000000000';
      final labelAr = CurrencyUtils.getPaymentMethodLabel(
        customKey,
        l10nAr,
        customLabelAr: 'زين كاش',
        customLabelEn: 'Zain Cash',
      );
      final labelEn = CurrencyUtils.getPaymentMethodLabel(
        customKey,
        l10nEn,
        customLabelAr: 'زين كاش',
        customLabelEn: 'Zain Cash',
      );
      expect(labelAr, 'زين كاش');
      expect(labelEn, 'Zain Cash');
    });

    test('PaymentMethod model label method respects langCode', () {
      const pm = PaymentMethod(
        key: 'custom_123',
        labelAr: 'برافو كاش',
        labelEn: 'Bravo Cash',
      );
      expect(pm.label('ar'), 'برافو كاش');
      expect(pm.label('en'), 'Bravo Cash');
    });
  });

  group('7. PosCart integration with line-level tax rate', () {
    test('PosCart preserves product tax rate into DocumentItemInput', () {
      final cart = PosCart();
      const productStandard = Product(
        id: 1,
        name: 'Standard item',
        salePrice: 100.0,
        stockQuantity: 10.0,
        isTaxable: true,
      );
      const productZeroRated = Product(
        id: 2,
        name: 'Zero-rated staple',
        salePrice: 50.0,
        stockQuantity: 10.0,
        isTaxable: true,
      );

      cart.add(productStandard, quantity: 1, taxRate: 15.0);
      cart.add(productZeroRated, quantity: 2, taxRate: 0.0);

      final inputs = cart.toItemInputs();
      expect(inputs.length, 2);
      expect(inputs[0].taxRate, 15.0);
      expect(inputs[1].taxRate, 0.0);

      final totals = cart.totals(taxRate: 15.0, pricesIncludeTax: false);
      // Item 0: 100 * 15% = 15.0 tax
      // Item 1: 100 * 0% = 0.0 tax
      // Subtotal = 200, tax = 15.0, total = 215.0
      expect(totals.subtotal, 200.0);
      expect(totals.taxAmount, 15.0);
      expect(totals.total, 215.0);
    });
  });

  group('8. Multi-currency reporting segregation', () {
    test('PurchaseReportSummary segregates totals by currency', () {
      final summary = PurchaseReportSummary(
        items: [],
        totalPurchases: 50100.0, // Nominal raw sum
        totalPaid: 50000.0,
        totalRemaining: 100.0,
        cancelledCount: 0,
        currencies: {'SDG', 'USD'},
        totalsByCurrency: {
          'SDG': (purchases: 50000.0, paid: 50000.0, remaining: 0.0),
          'USD': (purchases: 100.0, paid: 0.0, remaining: 100.0),
        },
      );

      expect(summary.currencies.length, 2);
      expect(summary.totalsByCurrency['SDG']!.purchases, 50000.0);
      expect(summary.totalsByCurrency['USD']!.purchases, 100.0);
      expect(summary.totalsByCurrency['USD']!.remaining, 100.0);
    });
  });
}
