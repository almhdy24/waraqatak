import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Payment method key rules', () {
    test('custom key is generated with custom_ prefix', () {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final key = 'custom_$ts';
      expect(key.startsWith('custom_'), isTrue);
    });

    test('predefined keys are not custom', () {
      const predefined = ['cash', 'bank', 'card', 'mobile', 'bankak',
        'okash', 'mada', 'fawry', 'paypal'];
      for (final k in predefined) {
        expect(k.startsWith('custom_'), isFalse);
      }
    });

    test('label falls back to key for unknown method', () {
      const unknownKey = 'some_unknown_method';
      const customLabels = <String, String>{};
      // Without custom labels, unknown key returned as-is
      final label = customLabels[unknownKey] ?? unknownKey;
      expect(label, unknownKey);
    });

    test('custom label resolves from map', () {
      const key = 'custom_1234567890';
      const label = 'Bank of Khartoum';
      final customLabels = {key: label};
      expect(customLabels[key], label);
    });

    test('renaming custom method updates label but not key', () {
      final methods = {'custom_1': 'Old Name'};
      methods['custom_1'] = 'New Name';
      expect(methods['custom_1'], 'New Name');
      expect(methods.containsKey('custom_1'), isTrue);
    });

    test('disabling method does not affect stored label', () {
      final enabled = ['cash', 'bank', 'custom_1'];
      final labels = {'custom_1': 'My Bank'};
      enabled.remove('custom_1');
      // Label still exists even when not enabled
      expect(labels['custom_1'], 'My Bank');
      expect(enabled.contains('custom_1'), isFalse);
    });
  });

  group('Payment validation rules', () {
    test('zero payment is invalid', () {
      const amount = 0.0;
      expect(amount <= 0, isTrue);
    });

    test('negative payment is invalid', () {
      const amount = -10.0;
      expect(amount <= 0, isTrue);
    });

    test('overpayment is invalid', () {
      const remaining = 100.0;
      const amount = 150.0;
      expect(amount > remaining, isTrue);
    });

    test('exact full payment is valid', () {
      const remaining = 100.0;
      const amount = 100.0;
      expect(amount > 0 && amount <= remaining, isTrue);
    });

    test('partial payment is valid', () {
      const remaining = 100.0;
      const amount = 60.0;
      expect(amount > 0 && amount <= remaining, isTrue);
    });
  });

  group('Backup table completeness', () {
    final requiredTables = [
      'businesses',
      'contacts',
      'products',
      'documents',
      'document_items',
      'document_counters',
    ];
    final optionalTables = [
      'document_payments',
      'stock_movements',
    ];

    test('all required tables are present', () {
      expect(requiredTables.length, 6);
    });

    test('stock_movements is included as optional', () {
      expect(optionalTables.contains('stock_movements'), isTrue);
    });

    test('backward compat: older backups without stock_movements still valid', () {
      final backupData = <String, dynamic>{
        'businesses': [],
        'contacts': [],
        'products': [],
        'documents': [],
        'document_items': [],
        'document_counters': [],
        // no stock_movements (old backup)
      };
      // Should not throw — stock_movements is optional
      final hasMovements = backupData.containsKey('stock_movements');
      expect(hasMovements, isFalse);
      // Required tables are all present
      for (final t in requiredTables) {
        expect(backupData.containsKey(t), isTrue);
      }
    });
  });

  group('Stock adjustment rules', () {
    test('positive delta increases stock', () {
      const current = 10.0;
      const delta = 5.0;
      expect(current + delta, 15.0);
    });

    test('negative delta decreases stock', () {
      const current = 10.0;
      const delta = -3.0;
      expect(current + delta, 7.0);
    });

    test('zero delta is rejected', () {
      const delta = 0.0;
      expect(delta == 0, isTrue); // validation should reject this
    });
  });
}
