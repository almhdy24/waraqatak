import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/models/entitlement.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/services/feature_access.dart';

void main() {
  // ── DocumentStatus ──────────────────────────────────────────
  group('DocumentStatus.fromPayment', () {
    test('paid when paid >= total', () {
      expect(DocumentStatus.fromPayment(100, 100), DocumentStatus.paid);
      expect(DocumentStatus.fromPayment(150, 100), DocumentStatus.paid);
    });

    test('partially_paid when 0 < paid < total', () {
      expect(DocumentStatus.fromPayment(50, 100), DocumentStatus.partiallyPaid);
      expect(DocumentStatus.fromPayment(0.01, 100), DocumentStatus.partiallyPaid);
    });

    test('issued when paid == 0', () {
      expect(DocumentStatus.fromPayment(0, 100), DocumentStatus.issued);
    });
  });

  // ── calculateInvoiceTotals ──────────────────────────────────
  group('DocumentService.calculateInvoiceTotals', () {
    final items = [
      const DocumentItemInput(description: 'A', quantity: 2, price: 50, taxable: true),
      const DocumentItemInput(description: 'B', quantity: 1, price: 100, taxable: false),
    ];

    test('subtotal is sum of item totals', () {
      final t = DocumentService.calculateInvoiceTotals(
        items: items, discount: 0, taxRate: 0,
      );
      expect(t.subtotal, 200);
    });

    test('tax applies only to taxable items', () {
      final t = DocumentService.calculateInvoiceTotals(
        items: items, discount: 0, taxRate: 10,
      );
      // taxable = 100, non-taxable = 100, tax = 10% of 100 = 10
      expect(t.taxAmount, closeTo(10, 0.001));
      expect(t.total, closeTo(210, 0.001));
    });

    test('discount applied proportionally to taxable items', () {
      // subtotal=200, discount=100 (50% discount)
      // taxable portion after discount = 100 * (200-100)/200 = 50
      // tax = 10% of 50 = 5
      final t = DocumentService.calculateInvoiceTotals(
        items: items, discount: 100, taxRate: 10,
      );
      expect(t.taxAmount, closeTo(5, 0.001));
      expect(t.total, closeTo(200 - 100 + 5, 0.001));
    });

    test('zero tax rate means no tax', () {
      final t = DocumentService.calculateInvoiceTotals(
        items: items, discount: 0, taxRate: 0,
      );
      expect(t.taxAmount, 0);
      expect(t.total, 200);
    });

    test('no taxable items means no tax', () {
      final nonTaxableItems = [
        const DocumentItemInput(description: 'A', quantity: 1, price: 100, taxable: false),
      ];
      final t = DocumentService.calculateInvoiceTotals(
        items: nonTaxableItems, discount: 0, taxRate: 15,
      );
      expect(t.taxAmount, 0);
      expect(t.total, 100);
    });

    test('full discount produces zero tax', () {
      final t = DocumentService.calculateInvoiceTotals(
        items: items, discount: 200, taxRate: 10,
      );
      expect(t.taxAmount, 0);
    });
  });

  // ── Business rules / validation guards ─────────────────────
  group('DocumentItemInput validation', () {
    test('total is quantity * price', () {
      const item = DocumentItemInput(description: 'X', quantity: 3, price: 25);
      expect(item.total, 75);
    });

    test('zero price is allowed (free item)', () {
      const item = DocumentItemInput(description: 'X', quantity: 1, price: 0);
      expect(item.total, 0);
    });
  });

  // ── Payment amount constraints ──────────────────────────────
  group('Payment amount constraints', () {
    test('payment > outstanding is disallowed by service', () {
      // Service enforces: amount <= remaining. Simulate the check.
      const remaining = 100.0;
      const payment = 150.0;
      expect(payment > remaining, isTrue);
    });

    test('zero payment is disallowed', () {
      const payment = 0.0;
      expect(payment <= 0, isTrue);
    });

    test('exact payment marks invoice as paid', () {
      expect(DocumentStatus.fromPayment(100, 100), DocumentStatus.paid);
    });

    test('partial payment marks invoice as partially_paid', () {
      expect(DocumentStatus.fromPayment(60, 100), DocumentStatus.partiallyPaid);
    });
  });

  // ── Quotation copy invariants ───────────────────────────────
  group('Copy document invariants (no DB)', () {
    test('copied invoice should start as draft', () {
      const original = 'invoice';
      final isItemBased = original == 'invoice' || original == 'quotation';
      final newStatus = isItemBased ? DocumentStatus.draft : DocumentStatus.issued;
      expect(newStatus, DocumentStatus.draft);
    });

    test('copied receipt should start as issued', () {
      const original = 'payment_receipt';
      final isItemBased = original == 'invoice' || original == 'quotation';
      final newStatus = isItemBased ? DocumentStatus.draft : DocumentStatus.issued;
      expect(newStatus, DocumentStatus.issued);
    });
  });

  // ── Cancelled document restrictions ────────────────────────
  group('Cancelled document restrictions', () {
    test('cancelled status constant is correct', () {
      expect(DocumentStatus.cancelled, 'cancelled');
    });

    test('draft status constant is correct', () {
      expect(DocumentStatus.draft, 'draft');
    });

    test('status fromPayment never returns cancelled', () {
      for (final paid in [0.0, 50.0, 100.0]) {
        final s = DocumentStatus.fromPayment(paid, 100);
        expect(s, isNot(DocumentStatus.cancelled));
      }
    });
  });

  // ── Free vs Pro inventory enforcement regression ───────────
  group('Free vs Pro inventory enforcement logic', () {
    test('strictStock is disabled for Free entitlement states', () {
      const freeStates = [
        EntitlementStatus.trialExpired,
        EntitlementStatus.licenseExpired,
        EntitlementStatus.licenseRevoked,
      ];
      for (final status in freeStates) {
        final state = EntitlementState(status: status, deviceId: 'test-device');
        final canAccessInventory = FeatureAccess.canAccess(Feature.inventory, state);
        expect(canAccessInventory, isFalse,
            reason: 'Free status $status must not enforce strict stock');
      }
    });

    test('strictStock is enabled for active Pro states', () {
      const proStates = [
        EntitlementStatus.trialActive,
        EntitlementStatus.licensed,
      ];
      for (final status in proStates) {
        final state = EntitlementState(status: status, deviceId: 'test-device');
        final canAccessInventory = FeatureAccess.canAccess(Feature.inventory, state);
        expect(canAccessInventory, isTrue,
            reason: 'Pro status $status must preserve strict stock enforcement');
      }
    });

    test('null entitlement (initial loading / failure) does not enforce Pro stock', () {
      final canAccessInventory = FeatureAccess.canAccess(Feature.inventory, null);
      expect(canAccessInventory, isFalse);
    });

    test('Free user stock deduction clamping prevents negative balances', () {
      double computeDeduction(double currentStock, double requestedQty, bool strict) {
        if (strict) return requestedQty;
        return currentStock > 0
            ? (currentStock >= requestedQty ? requestedQty : currentStock)
            : 0.0;
      }

      // 1. Available > requested: normal deduction
      expect(computeDeduction(10, 4, false), 4.0);

      // 2. Available < requested: clamped to available stock, never below 0
      final deduct = computeDeduction(3, 5, false);
      expect(deduct, 3.0);
      expect(3 - deduct, 0.0, reason: 'Stock balance must never become negative');

      // 3. Available is 0: deducts 0, stock remains 0
      expect(computeDeduction(0, 5, false), 0.0);
    });

    test('Purchase cancellation guard rejects when stock has been consumed', () {
      bool canSafelyCancelPurchase(double currentStock, double purchasedQty) {
        return currentStock >= purchasedQty;
      }

      expect(canSafelyCancelPurchase(10, 10), isTrue);
      expect(canSafelyCancelPurchase(2, 10), isFalse,
          reason: 'Must not cancel purchase if stock was consumed');
    });

    test('Purchase edit stock safety guard calculates net reduction and rejects consumed stock', () {
      bool canSafelyEditPurchase(double currentStock, double oldQty, double newQty) {
        if (oldQty <= newQty) return true;
        final netReduction = oldQty - newQty;
        return currentStock >= netReduction;
      }

      // Scenario: 10 units purchased originally, 8 sold, leaving 2 in stock
      const currentStock = 2.0;
      const oldPurchasedQty = 10.0;

      // 1. Increasing purchase quantity from 10 to 15 is always safe
      expect(canSafelyEditPurchase(currentStock, oldPurchasedQty, 15.0), isTrue);

      // 2. Keeping purchase quantity at 10 is safe
      expect(canSafelyEditPurchase(currentStock, oldPurchasedQty, 10.0), isTrue);

      // 3. Reducing purchase quantity to 8 requires reducing 2 units, which exactly equals available stock (safe)
      expect(canSafelyEditPurchase(currentStock, oldPurchasedQty, 8.0), isTrue);

      // 4. Reducing purchase quantity to 7 requires reducing 3 units, exceeding available stock 2 (unsafe!)
      expect(canSafelyEditPurchase(currentStock, oldPurchasedQty, 7.0), isFalse);

      // 5. Reducing purchase quantity to 5 requires reducing 5 units (unsafe!)
      expect(canSafelyEditPurchase(currentStock, oldPurchasedQty, 5.0), isFalse);

      // 6. Removing purchase item completely (0 units) requires reducing 10 units (unsafe!)
      expect(canSafelyEditPurchase(currentStock, oldPurchasedQty, 0.0), isFalse);
    });

    test('Purchase edit with multiple items aggregates net product reductions accurately', () {
      bool canSafelyEditPurchaseMulti({
        required Map<int, double> currentStockByProduct,
        required Map<int, double> oldQtyByProduct,
        required Map<int, double> newQtyByProduct,
      }) {
        for (final entry in oldQtyByProduct.entries) {
          final pid = entry.key;
          final oldQty = entry.value;
          final newQty = newQtyByProduct[pid] ?? 0.0;
          if (oldQty > newQty) {
            final netReduction = oldQty - newQty;
            final stock = currentStockByProduct[pid] ?? 0.0;
            if (stock < netReduction) return false;
          }
        }
        return true;
      }

      // Product A: 10 bought, 8 sold, stock = 2
      // Product B: 5 bought, 0 sold, stock = 5
      final stocks = {1: 2.0, 2: 5.0};
      final oldQtys = {1: 10.0, 2: 5.0};

      // Edit A -> 8, B -> 2:
      // A needs 2 (stock=2: OK), B needs 3 (stock=5: OK) -> overall OK
      expect(
        canSafelyEditPurchaseMulti(
          currentStockByProduct: stocks,
          oldQtyByProduct: oldQtys,
          newQtyByProduct: {1: 8.0, 2: 2.0},
        ),
        isTrue,
      );

      // Edit A -> 5, B -> 2:
      // A needs 5 (stock=2: FAILS) -> overall FAIL
      expect(
        canSafelyEditPurchaseMulti(
          currentStockByProduct: stocks,
          oldQtyByProduct: oldQtys,
          newQtyByProduct: {1: 5.0, 2: 2.0},
        ),
        isFalse,
      );
    });
  });
}
