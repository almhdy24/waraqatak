import 'dart:ui' as ui;

import '../database/database_helper.dart';
import '../models/app_notification.dart';

/// Manages system and licensing in-app notifications in SQLite.
///
/// Features:
/// - Deterministic negative IDs to prevent collision with remote announcements.
/// - Clear bilingual messages (Arabic primary with English contextual hints).
/// - Deduplication and read/unread persistence across app launches.
/// - Cleanup of stale success messages when a license is revoked.
/// - Direct deep-link navigation (`app://license`).
/// - Zero secret leakage (never exposes key strings or tokens).
class LicenseNotificationService {
  LicenseNotificationService._();
  static final LicenseNotificationService instance =
      LicenseNotificationService._();

  static const int idTrialActive = -101;
  static const int idTrialExpiring = -102;
  static const int idTrialExpired = -103;
  static const int idLicenseActive = -104;
  static const int idLicenseExpiring = -105;
  static const int idLicenseExpired = -106;
  static const int idLicenseRevoked = -107;
  static const int idServerNotice = -108;

  bool get _isArabic {
    final locale = ui.PlatformDispatcher.instance.locale;
    return locale.languageCode.toLowerCase() == 'ar';
  }

  /// Post or update trial started notification.
  Future<void> onTrialStarted({required int daysRemaining}) async {
    final isAr = _isArabic;
    final title = isAr
        ? 'بدء الفترة التجريبية المجانية'
        : 'Free Trial Started';
    final body = isAr
        ? 'مرحباً بك في تطبيق ورقتك! استمتع بكافة الميزات الاحترافية خلال فترتك التجريبية المتبقي منها $daysRemaining يوماً.'
        : 'Welcome to Waraqatak! Enjoy full Pro features during your 14-day free trial ($daysRemaining days remaining).';

    await _upsert(
      serverId: idTrialActive,
      title: title,
      body: body,
      category: 'announcement',
      actionUrl: 'app://license',
    );
  }

  /// Post or update trial expiring notification.
  Future<void> onTrialExpiring({required int daysRemaining}) async {
    final isAr = _isArabic;
    final title = isAr
        ? 'تنبيه: اقتراب انتهاء الفترة التجريبية'
        : 'Notice: Trial Expiring Soon';
    final body = isAr
        ? 'تبقى $daysRemaining أيام فقط على انتهاء فترتك التجريبية المجانية. قم بتفعيل ترخيصك لمواصلة استخدام الميزات الاحترافية دون انقطاع.'
        : 'Only $daysRemaining days left in your free trial. Activate a license to continue using Pro features without interruption.';

    await _upsert(
      serverId: idTrialExpiring,
      title: title,
      body: body,
      category: 'critical',
      actionUrl: 'app://license',
    );
  }

  /// Post trial expired notification and clean up active trial messages.
  Future<void> onTrialExpired() async {
    await _delete(idTrialActive);
    await _delete(idTrialExpiring);

    final isAr = _isArabic;
    final title = isAr
        ? 'انتهت الفترة التجريبية المجانية'
        : 'Free Trial Expired';
    final body = isAr
        ? 'انتهت الفترة التجريبية المجانية لتطبيق ورقتك. لا تزال المستندات والفواتير السابقة محفوظة ومتاحة. فعّل رمز الترخيص للاستمرار بالاستفادة من ميزات Pro.'
        : 'Your free trial has ended. Existing invoices and documents remain safe. Enter an activation key to unlock Pro features.';

    await _upsert(
      serverId: idTrialExpired,
      title: title,
      body: body,
      category: 'critical',
      actionUrl: 'app://license',
    );
  }

  /// Post license activated successfully and clean up revocation / expired notices.
  Future<void> onLicenseActivated({
    DateTime? expiresAt,
    String? licenseType,
  }) async {
    await _delete(idTrialActive);
    await _delete(idTrialExpiring);
    await _delete(idTrialExpired);
    await _delete(idLicenseRevoked);
    await _delete(idLicenseExpired);

    final isAr = _isArabic;
    final isPerpetual = expiresAt == null;
    final expStr = expiresAt?.toLocal().toString().split(' ').first;

    final title = isAr
        ? 'تم تفعيل الترخيص بنجاح'
        : 'License Activated Successfully';
    final body = isAr
        ? (isPerpetual
            ? 'تم تفعيل ترخيص ورقتك بنجاح على هذا الجهاز (ترخيص دائم). جميع الميزات الاحترافية متاحة الآن.'
            : 'تم تفعيل ترخيص ورقتك بنجاح على هذا الجهاز حتى $expStr.')
        : (isPerpetual
            ? 'Waraqatak license activated successfully on this device (Lifetime/Perpetual). Full Pro features unlocked.'
            : 'Waraqatak license activated successfully on this device until $expStr.');

    await _upsert(
      serverId: idLicenseActive,
      title: title,
      body: body,
      category: 'announcement',
      actionUrl: 'app://license',
    );
  }

  /// Post license expiring soon notification.
  Future<void> onLicenseExpiring({required int daysRemaining}) async {
    final isAr = _isArabic;
    final title = isAr
        ? 'تنبيه: اقتراب موعد انتهاء الترخيص'
        : 'Notice: License Expiring Soon';
    final body = isAr
        ? 'سينتهي ترخيص ورقتك خلال $daysRemaining يوماً. يرجى تجديد الترخيص لضمان استمرار المزامنة والميزات الاحترافية.'
        : 'Your Waraqatak license will expire in $daysRemaining days. Please renew to ensure continued access to Pro features.';

    await _upsert(
      serverId: idLicenseExpiring,
      title: title,
      body: body,
      category: 'critical',
      actionUrl: 'app://license',
    );
  }

  /// Post license expired notification.
  Future<void> onLicenseExpired() async {
    final isAr = _isArabic;
    final title = isAr
        ? 'انتهت صلاحية الترخيص'
        : 'License Expired';
    final body = isAr
        ? 'انتهت صلاحية ترخيص ورقتك على هذا الجهاز. يمكنك مراجعة فواتيرك وطباعتها في أي وقت، ولإعادة تفعيل الميزات المتقدمة قم بتجديد الترخيص.'
        : 'Your Waraqatak license on this device has expired. You can still view and print existing documents; renew to unlock Pro features.';

    await _upsert(
      serverId: idLicenseExpired,
      title: title,
      body: body,
      category: 'critical',
      actionUrl: 'app://license',
    );
  }

  /// Post license revoked notification and remove stale active success messages.
  Future<void> onLicenseRevoked({String? reason}) async {
    // Crucial security requirement: Never show stale success after revocation
    await _delete(idLicenseActive);
    await _delete(idLicenseExpiring);

    final isAr = _isArabic;
    final title = isAr
        ? 'تم إلغاء تفعيل الترخيص على الجهاز'
        : 'License Revoked on Device';
    final body = isAr
        ? 'تم إلغاء ترخيص هذا الجهاز من قبل خادم التراخيص (أو نقل الترخيص لجهاز آخر). للتحقق أو إدخال مفتاح جديد، انتقل لشاشة الترخيص.'
        : 'This device license has been revoked or transferred by the server. Go to the license screen to re-activate or check status.';

    await _upsert(
      serverId: idLicenseRevoked,
      title: title,
      body: body,
      category: 'critical',
      actionUrl: 'app://license',
    );
  }

  /// Server verification connectivity notice (distinguishes temporary connectivity from revocation).
  Future<void> onServerVerificationUnavailable() async {
    final isAr = _isArabic;
    final title = isAr
        ? 'تنبيه اتصال: تعذر التحقق اللحظي'
        : 'Connectivity: Temporary Verification Notice';
    final body = isAr
        ? 'تعذر الاتصال بخادم التراخيص مؤقتاً للتحقق. لا تقلق، يستمر التطبيق بالعمل بصورة طبيعية دون إيقاف.'
        : 'Unable to reach the licensing server momentarily. Your application continues to operate normally offline.';

    await _upsert(
      serverId: idServerNotice,
      title: title,
      body: body,
      category: 'tips',
      actionUrl: 'app://license',
    );
  }

  Future<void> _upsert({
    required int serverId,
    required String title,
    required String body,
    required String category,
    required String actionUrl,
  }) async {
    try {
      final notif = AppNotification(
        serverId: serverId,
        title: title,
        body: body,
        category: category,
        actionUrl: actionUrl,
        publishedAt: DateTime.now(),
        syncedAt: DateTime.now(),
      );
      await DatabaseHelper.instance.upsertCachedNotification(notif);
    } catch (_) {}
  }

  Future<void> _delete(int serverId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'cached_notifications',
        where: 'server_id = ?',
        whereArgs: [serverId],
      );
    } catch (_) {}
  }
}
