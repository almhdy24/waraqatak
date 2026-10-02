import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/localization/app_localizations.dart';

/// Guards that user-facing Pro / activation copy never leaks in-app purchase,
/// subscription-plan, or pricing language. Mirrors the CI shell script so a
/// regression is caught in-tree before it ever reaches a reviewer.
///
/// NOTE: Merchant-facing invoicing strings (recordPayment, paymentHistory,
/// paymentMethod, bankTransfer, …) are intentionally kept — they describe how
/// the business owner records their own customers' payments against invoices
/// and have nothing to do with buying anything inside the app. This file only
/// checks the Pro-gating / activation copy.
void main() {
  final ar = AppLocalizations('ar');
  final en = AppLocalizations('en');

  // Strings shown on the paywall sheet, locked-feature screen, and activation
  // screen — anything that a Play reviewer would read when exploring Pro.
  List<String> gatingStrings(AppLocalizations l) => [
        l.proFeatureTitle,
        l.proFeaturesActivation,
        l.getActivationKeyInfo,
        l.enterActivationKeyAction,
        l.invalidOrExpiredKey,
        l.proBadgeLabel,
        l.proIncludesPurchases,
        l.proIncludesInventory,
        l.proIncludesReports,
        l.freeDataAlwaysAvailable,
        l.activatedStatus,
      ];

  // English/latin forbidden terms. Must not appear in any gating string.
  const forbiddenEn = [
    'buy pro', 'purchase pro', 'subscribe', 'subscription plan',
    'checkout', 'price list', 'pay now', 'free trial then pay',
  ];

  // Arabic forbidden terms.
  const forbiddenAr = [
    'اشتر', 'اشتراك شهري', 'سعر الاشتراك', 'ادفع الآن', 'إتمام الشراء',
  ];

  group('Play compliance — gating copy (English)', () {
    for (final term in forbiddenEn) {
      test('"$term" is absent from every gating string', () {
        for (final s in gatingStrings(en)) {
          expect(s.toLowerCase().contains(term), isFalse,
              reason: '"$term" found in: $s');
        }
      });
    }
  });

  group('Play compliance — gating copy (Arabic)', () {
    for (final term in forbiddenAr) {
      test('"$term" is absent from every gating string', () {
        for (final s in gatingStrings(ar)) {
          expect(s.contains(term), isFalse,
              reason: '"$term" found in: $s');
        }
      });
    }
  });

  group('Mandated approved copy exists verbatim', () {
    test('AR: proFeaturesActivation matches policy-approved wording', () {
      expect(ar.proFeaturesActivation,
          'تُفعَّل الميزات الاحترافية بمفتاح تفعيل.');
    });

    test('EN: proFeaturesActivation matches policy-approved wording', () {
      expect(en.proFeaturesActivation,
          'Pro features are unlocked with an activation key.');
    });

    test('AR: getActivationKeyInfo directs user outside the app', () {
      // Must mention the website / WhatsApp acquisition path, with no price.
      expect(ar.getActivationKeyInfo, contains('موقعنا'));
      expect(ar.getActivationKeyInfo, contains('واتساب'));
    });

    test('EN: getActivationKeyInfo directs user outside the app', () {
      expect(en.getActivationKeyInfo.toLowerCase(), contains('website'));
      expect(en.getActivationKeyInfo.toLowerCase(), contains('whatsapp'));
    });

    test('invalidOrExpiredKey is a neutral failure message', () {
      // Must not suggest buying a new one — only "get a new one".
      expect(ar.invalidOrExpiredKey.contains('شراء'), isFalse);
      expect(en.invalidOrExpiredKey.toLowerCase().contains('buy'), isFalse);
      expect(en.invalidOrExpiredKey.toLowerCase().contains('purchase'), isFalse);
    });
  });

  group('Backup warning copy exists', () {
    test('AR: unencrypted backup warning present', () {
      expect(ar.backupUnencryptedTitle, isNotEmpty);
      expect(ar.backupUnencryptedWarning, contains('غير مشفرة'));
    });

    test('EN: unencrypted backup warning present', () {
      expect(en.backupUnencryptedTitle, isNotEmpty);
      expect(en.backupUnencryptedWarning.toLowerCase(),
          contains('unencrypted'));
    });
  });

  group('Open-source licenses copy exists', () {
    test('AR: licenses link + legalese present', () {
      expect(ar.openSourceLicenses, isNotEmpty);
      expect(ar.openSourceLicensesLegalese, contains('Tajawal'));
    });

    test('EN: licenses link + legalese present', () {
      expect(en.openSourceLicenses, isNotEmpty);
      expect(en.openSourceLicensesLegalese, contains('Tajawal'));
    });
  });
}
