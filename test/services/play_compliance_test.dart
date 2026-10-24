import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/core/constants/app_constants.dart';
import 'package:warqatek/localization/app_localizations.dart';

/// Guards that user-facing Pro / activation copy never leaks:
///   (a) in-app purchase, subscription-plan, or pricing language, OR
///   (b) wording that tells the user where / how to obtain an activation
///       key (website, WhatsApp, phone number, "contact us", URLs).
///
/// Mirrors the two-pass CI shell guard (`tool/check_play_compliance.sh`) so a
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
        l.enterActivationKey,
        l.enterActivationKeyAction,
        l.activationKeyHint,
        l.activate,
        l.activationSuccessTitle,
        l.activationSuccessBody,
        l.invalidOrExpiredKey,
        l.activationTooManyAttempts,
        l.activationServerUnreachable,
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

  // Acquisition-copy forbidden terms. The app must not tell the user where
  // or how to obtain an activation key — no URL, phone number, website,
  // WhatsApp, or "contact us" wording in any Pro-gating string.
  const forbiddenAcquisitionEn = [
    'website', 'whatsapp', 'contact us', 'contacting us', 'wa.me', 'http',
  ];
  const forbiddenAcquisitionAr = [
    'موقعنا', 'واتساب', 'تواصل معنا', 'التواصل معنا', 'راسلنا', 'اتصل بنا',
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

  group('Play compliance — acquisition copy (English)', () {
    for (final term in forbiddenAcquisitionEn) {
      test('"$term" is absent from every gating string', () {
        for (final s in gatingStrings(en)) {
          expect(s.toLowerCase().contains(term), isFalse,
              reason:
                  '"$term" directs the user outside the app in: $s');
        }
      });
    }
  });

  group('Play compliance — acquisition copy (Arabic)', () {
    for (final term in forbiddenAcquisitionAr) {
      test('"$term" is absent from every gating string', () {
        for (final s in gatingStrings(ar)) {
          expect(s.contains(term), isFalse,
              reason:
                  '"$term" directs the user outside the app in: $s');
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

    test('AR: getActivationKeyInfo is neutral and self-contained', () {
      expect(ar.getActivationKeyInfo,
          'أدخل مفتاح التفعيل لإلغاء قفل الميزات الاحترافية.');
    });

    test('EN: getActivationKeyInfo is neutral and self-contained', () {
      expect(en.getActivationKeyInfo,
          'Enter your activation key to unlock Pro features.');
    });

    test('invalidOrExpiredKey is a neutral failure message', () {
      // Must not suggest buying a new one — and must not direct the user
      // outside the app to obtain a replacement.
      expect(ar.invalidOrExpiredKey.contains('شراء'), isFalse);
      expect(en.invalidOrExpiredKey.toLowerCase().contains('buy'), isFalse);
      expect(en.invalidOrExpiredKey.toLowerCase().contains('purchase'),
          isFalse);
      expect(en.invalidOrExpiredKey.toLowerCase().contains('contact'),
          isFalse);
      expect(ar.invalidOrExpiredKey.contains('تواصل'), isFalse);
    });

    test('activationTooManyAttempts is a neutral retry message', () {
      expect(en.activationTooManyAttempts.toLowerCase().contains('contact'),
          isFalse);
      expect(en.activationTooManyAttempts.toLowerCase().contains('buy'),
          isFalse);
      expect(ar.activationTooManyAttempts.contains('تواصل'), isFalse);
      expect(ar.activationTooManyAttempts.contains('شراء'), isFalse);
    });

    test('activationServerUnreachable never shown as "invalid key"', () {
      expect(en.activationServerUnreachable.toLowerCase().contains('invalid'),
          isFalse);
      expect(en.activationServerUnreachable.toLowerCase().contains('contact'),
          isFalse);
      expect(ar.activationServerUnreachable.contains('غير صالح'), isFalse);
      expect(ar.activationServerUnreachable.contains('تواصل'), isFalse);
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

  group('URL allowlist — AppConstants outbound links', () {
    // The ONLY outbound URLs the app is permitted to open. The shell guard
    // (`tool/check_play_compliance.sh` → Pass 3) scans the reviewer-visible
    // screens for the same allowlist; this test anchors the constants
    // and makes any new URL constant a diff that will be noticed in review.
    const allowed = {
      'https://almhdy24.com/products/waraqatak/privacy.html',
      'https://almhdy24.com/products/waraqatak/terms.html',
      'https://almhdy24.com/products/waraqatak/delete.html',
      'https://almhdy24.com/products/waraqatak/help/',
    };

    test('product-site URLs match the allowlist exactly', () {
      expect(allowed, contains(AppConstants.privacyPolicyUrl));
      expect(allowed, contains(AppConstants.termsUrl));
      expect(allowed, contains(AppConstants.deleteDataUrl));
      expect(allowed, contains(AppConstants.helpCenterUrl));
    });

    test('each URL is https and lives on almhdy24.com/products/waraqatak/',
        () {
      for (final url in [
        AppConstants.privacyPolicyUrl,
        AppConstants.termsUrl,
        AppConstants.deleteDataUrl,
        AppConstants.helpCenterUrl,
      ]) {
        expect(url.startsWith('https://almhdy24.com/products/waraqatak/'),
            isTrue, reason: '$url does not match the product-site prefix');
      }
    });

    test('support email is a plain address', () {
      expect(AppConstants.supportEmail, contains('@'));
      expect(AppConstants.supportEmail.toLowerCase().contains('http'),
          isFalse);
      expect(AppConstants.supportEmail.contains('+'), isFalse);
    });

    test('support links are exactly the allowlisted channels', () {
      // Mirrors SUPPORT_URL_RE in tool/check_play_compliance.sh. These are
      // help/contact channels shown on the About screen only.
      expect(AppConstants.whatsappUrl, 'https://wa.me/249993452125');
      expect(AppConstants.facebookPageUrl,
          'https://www.facebook.com/profile.php?id=61593843478292');
      expect(AppConstants.websiteUrl, 'https://almhdy24.com');
      expect(AppConstants.playStoreUrl,
          'https://play.google.com/store/apps/details?id=com.elmahdi.waraqatak');
    });
  });

  group('Support copy never mentions keys, prices or purchasing', () {
    for (final l in [ar, en]) {
      final support = [
        l.supportAndContact,
        l.whatsappSupport,
        l.whatsappSupportDesc,
        l.supportWhatsAppGreeting,
        l.facebookPage,
        l.facebookPageDesc,
        l.developerWebsite,
        l.getHelp,
        l.shareAppMessage,
      ];
      test('${l.langCode}: support strings are neutral', () {
        const forbidden = [
          'key', 'activation', 'pro', 'price', 'buy', 'purchase',
          'subscribe', 'pay',
          'مفتاح', 'تفعيل', 'سعر', 'شراء', 'اشتر', 'اشتراك', 'ادفع', 'دفع',
        ];
        for (final text in support) {
          final lower = text.toLowerCase();
          for (final term in forbidden) {
            expect(RegExp('\\b$term\\b').hasMatch(lower) ||
                    (term.codeUnitAt(0) > 127 && lower.contains(term)),
                isFalse,
                reason: '"$term" found in support copy: $text');
          }
        }
      });
    }
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
