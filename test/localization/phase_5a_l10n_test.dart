import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/localization/app_localizations.dart';

void main() {
  group('Phase 5A Localization Keys', () {
    late AppLocalizations l10nAr;
    late AppLocalizations l10nEn;

    setUp(() {
      l10nAr = AppLocalizations('ar');
      l10nEn = AppLocalizations('en');
    });

    final keys = <String, (String Function(), String Function())>{
      'removeDeviceLicenseTitle': (
        () => l10nAr.removeDeviceLicenseTitle,
        () => l10nEn.removeDeviceLicenseTitle,
      ),
      'voucherLoadingBalance': (
        () => l10nAr.voucherLoadingBalance,
        () => l10nEn.voucherLoadingBalance,
      ),
      'voucherBalanceLoadFailed': (
        () => l10nAr.voucherBalanceLoadFailed,
        () => l10nEn.voucherBalanceLoadFailed,
      ),
      'voucherSelectCustomerHint': (
        () => l10nAr.voucherSelectCustomerHint,
        () => l10nEn.voucherSelectCustomerHint,
      ),
      'roleOwner': (() => l10nAr.roleOwner, () => l10nEn.roleOwner),
      'roleAdministrator': (
        () => l10nAr.roleAdministrator,
        () => l10nEn.roleAdministrator,
      ),
      'cannotDisableLastMethod': (
        () => l10nAr.cannotDisableLastMethod,
        () => l10nEn.cannotDisableLastMethod,
      ),
      'cannotDisableDefaultMethod': (
        () => l10nAr.cannotDisableDefaultMethod,
        () => l10nEn.cannotDisableDefaultMethod,
      ),
      'switchToBaseTitle': (
        () => l10nAr.switchToBaseTitle,
        () => l10nEn.switchToBaseTitle,
      ),
      'lowStockConfirmTitle': (
        () => l10nAr.lowStockConfirmTitle,
        () => l10nEn.lowStockConfirmTitle,
      ),
      'lowStockConfirmMessage': (
        () => l10nAr.lowStockConfirmMessage('Item A'),
        () => l10nEn.lowStockConfirmMessage('Item A'),
      ),
      'continueAnyway': (
        () => l10nAr.continueAnyway,
        () => l10nEn.continueAnyway,
      ),
      'pdfResetConfirmTitle': (
        () => l10nAr.pdfResetConfirmTitle,
        () => l10nEn.pdfResetConfirmTitle,
      ),
      'pdfResetConfirmMessage': (
        () => l10nAr.pdfResetConfirmMessage,
        () => l10nEn.pdfResetConfirmMessage,
      ),
      'confirmSetPeriodLockWithDate': (
        () => l10nAr.confirmSetPeriodLockWithDate('2026-01-01'),
        () => l10nEn.confirmSetPeriodLockWithDate('2026-01-01'),
      ),
      'taxProfileInUse': (
        () => l10nAr.taxProfileInUse(3),
        () => l10nEn.taxProfileInUse(3),
      ),
      'taxRateRange': (() => l10nAr.taxRateRange, () => l10nEn.taxRateRange),
      'clearFilters': (() => l10nAr.clearFilters, () => l10nEn.clearFilters),
      'unitRemoved': (
        () => l10nAr.unitRemoved('Box'),
        () => l10nEn.unitRemoved('Box'),
      ),
      'logoInvalidImage': (
        () => l10nAr.logoInvalidImage,
        () => l10nEn.logoInvalidImage,
      ),
      'csvPreviewLimited': (
        () => l10nAr.csvPreviewLimited(10, 50),
        () => l10nEn.csvPreviewLimited(10, 50),
      ),
    };

    for (final entry in keys.entries) {
      test('key "${entry.key}" has non-empty and different Ar/En values', () {
        final ar = entry.value.$1();
        final en = entry.value.$2();

        expect(
          ar.trim(),
          isNotEmpty,
          reason: 'Arabic for ${entry.key} is empty',
        );
        expect(
          en.trim(),
          isNotEmpty,
          reason: 'English for ${entry.key} is empty',
        );
        expect(
          ar,
          isNot(equals(en)),
          reason: '${entry.key} has identical Arabic and English',
        );
      });
    }
  });
}
