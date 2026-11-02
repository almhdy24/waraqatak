class AppConstants {
  static const String appName = 'Waraqatak';
  static const String packageName = 'com.elmahdi.waraqatak';
  static const String appId = 'com.elmahdi.waraqatak';

  /// Semantic version of the application.
  static const String appVersion = '1.1.5';

  /// Monotonically increasing build number.
  static const int appBuild = 21;

  /// Short display name of the developer / publisher.
  static const String developerName = 'Elmahdi Abdallh';
  static const String developerBrand = 'Elmahdi Dev';

  // ── Support channels (About screen only) ────────────────────────────────
  // Support/help contact only. The About screen must never pair these with
  // activation-key, price or purchase wording (see docs/play-compliance.md).
  static const String supportEmail = 'support@almhdy24.com';

  /// WhatsApp number in international format without "+" or spaces.
  static const String whatsappNumber = '249993452125';
  static const String whatsappUrl = 'https://wa.me/249993452125';
  static const String facebookPageUrl =
      'https://www.facebook.com/profile.php?id=61593843478292';
  static const String websiteUrl = 'https://almhdy24.com';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.elmahdi.waraqatak';

  // ── Website URL allowlist ───────────────────────────────────────────────
  // Every URL the app opens is declared here and allowlisted by the
  // compliance guard (tool/check_play_compliance.sh). If you need another
  // link, update the guard and `docs/play-compliance.md` first.
  static const String helpCenterUrl =
      'https://almhdy24.com/products/waraqatak/help/';
  static const String privacyPolicyUrl =
      'https://almhdy24.com/products/waraqatak/privacy.html';
  static const String termsUrl =
      'https://almhdy24.com/products/waraqatak/terms.html';
  static const String deleteDataUrl =
      'https://almhdy24.com/products/waraqatak/delete.html';
}
