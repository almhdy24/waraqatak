class AppConstants {
  static const String appName = 'Waraqatak';

  /// Only outbound channel exposed from the app itself.
  /// Rendered as a `mailto:` tile on the About screen.
  static const String supportEmail = 'support@almhdy24.com';

  /// Short display name of the developer / publisher.
  static const String developerName = 'Elmahdi Abdallh';

  // ── Website URL allowlist ───────────────────────────────────────────────
  // The ONLY three URLs the app is permitted to open. The compliance guard
  // scans About / License / activation / transparency screens for any
  // other URL and fails the build. If you need another link, update the
  // guard and `docs/play-compliance.md` first.
  static const String privacyPolicyUrl =
      'https://almhdy24.com/products/waraqatak/privacy.html';
  static const String termsUrl =
      'https://almhdy24.com/products/waraqatak/terms.html';
  static const String deleteDataUrl =
      'https://almhdy24.com/products/waraqatak/delete.html';
}
