import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/services/access/access_error.dart';
import 'package:warqatek/services/access/access_messages.dart';
import 'package:warqatek/utils/error_utils.dart';

void main() {
  group('ErrorUtils.toFriendlyMessage localized known exceptions', () {
    final l10nAr = AppLocalizations('ar');
    final l10nEn = AppLocalizations('en');

    final testCases = <Map<String, dynamic>>[
      {
        'error': StateError('Cannot delete product with existing invoice or purchase history'),
        'expectedAr': l10nAr.errorDeleteProductHasHistory,
        'expectedEn': l10nEn.errorDeleteProductHasHistory,
      },
      {
        'error': ArgumentError('Discount cannot exceed subtotal'),
        'expectedAr': l10nAr.errorDiscountExceedsSubtotal,
        'expectedEn': l10nEn.errorDiscountExceedsSubtotal,
      },
      {
        'error': ArgumentError('Paid amount cannot exceed total'),
        'expectedAr': l10nAr.errorPaidExceedsTotal,
        'expectedEn': l10nEn.errorPaidExceedsTotal,
      },
      {
        'error': ArgumentError('Amount cannot be negative'),
        'expectedAr': l10nAr.errorNegativeAmount,
        'expectedEn': l10nEn.errorNegativeAmount,
      },
      {
        'error': ArgumentError('Unit price cannot be negative'),
        'expectedAr': l10nAr.errorNegativeAmount,
        'expectedEn': l10nEn.errorNegativeAmount,
      },
      {
        'error': Exception('Value cannot be negative'),
        'expectedAr': l10nAr.errorNegativeAmount,
        'expectedEn': l10nEn.errorNegativeAmount,
      },
      {
        'error': ArgumentError('validUntil must be on or after date'),
        'expectedAr': l10nAr.errorValidUntilBeforeDate,
        'expectedEn': l10nEn.errorValidUntilBeforeDate,
      },
      {
        'error': StateError('Valid-until date cannot be before issue date'),
        'expectedAr': l10nAr.errorValidUntilBeforeDate,
        'expectedEn': l10nEn.errorValidUntilBeforeDate,
      },
    ];

    for (final tc in testCases) {
      final err = tc['error'] as Object;
      test('maps "$err" to localized string in AR and EN', () {
        expect(ErrorUtils.toFriendlyMessage(err, l10nAr), equals(tc['expectedAr']));
        expect(ErrorUtils.toFriendlyMessage(err, l10nEn), equals(tc['expectedEn']));
      });
    }

    test('maps PermissionDeniedException to localized string in AR and EN', () {
      const err = PermissionDeniedException('products.manage');
      expect(
        ErrorUtils.toFriendlyMessage(err, l10nAr),
        equals(l10nAr.accessDeniedMissingPerm(localizedPermissionName(l10nAr, 'products.manage'))),
      );
      expect(
        ErrorUtils.toFriendlyMessage(err, l10nEn),
        equals(l10nEn.accessDeniedMissingPerm(localizedPermissionName(l10nEn, 'products.manage'))),
      );
    });
  });
}
