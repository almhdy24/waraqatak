import '../core/constants/app_constants.dart';
import '../services/app_ops_service.dart';

/// Represents a subscription plan option in Waraqatak Pro.
class SubscriptionPlan {
  final String id;
  final int durationMonths;
  final int priceSdg;
  final int? originalPriceSdg;
  final int? savingsSdg;
  final int? discountPercent;
  final int? monthlyEquivalentSdg;
  final bool isFeatured;

  const SubscriptionPlan({
    required this.id,
    required this.durationMonths,
    required this.priceSdg,
    this.originalPriceSdg,
    this.savingsSdg,
    this.discountPercent,
    this.monthlyEquivalentSdg,
    this.isFeatured = false,
  });

  /// The standard subscription tiers offered in SDG.
  /// The 1-Year plan is featured with 33% discount (saves 60,000 SDG).
  static const List<SubscriptionPlan> allPlans = [
    SubscriptionPlan(
      id: '1_year',
      durationMonths: 12,
      priceSdg: 120000,
      originalPriceSdg: 180000,
      savingsSdg: 60000,
      discountPercent: 33,
      monthlyEquivalentSdg: 10000,
      isFeatured: true,
    ),
    SubscriptionPlan(
      id: '6_months',
      durationMonths: 6,
      priceSdg: 70000,
      savingsSdg: 20000,
    ),
    SubscriptionPlan(
      id: '3_months',
      durationMonths: 3,
      priceSdg: 40000,
      savingsSdg: 5000,
    ),
    SubscriptionPlan(
      id: '1_month',
      durationMonths: 1,
      priceSdg: 15000,
    ),
  ];

  /// Formats an integer amount into thousands-separated string (e.g. 120000 -> "120,000").
  static String formatSdg(int amount) {
    return amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  /// Retrieves the support WhatsApp number from remote config or default constants.
  static String getSupportWhatsAppNumber() {
    final remote = AppOpsService.instance.getString('support_whatsapp');
    if (remote != null && remote.trim().isNotEmpty) {
      final sanitized = remote.trim().replaceAll(RegExp(r'[^0-9]'), '');
      if (sanitized.isNotEmpty) return sanitized;
    }
    return AppConstants.whatsappNumber;
  }

  /// Constructs the prefilled message for WhatsApp subscription inquiries.
  static String generateWhatsAppMessage({
    required SubscriptionPlan plan,
    required String planTitle,
    required String durationText,
    String? deviceId,
    bool isArabic = true,
  }) {
    final priceStr = formatSdg(plan.priceSdg);
    final cleanDeviceId = (deviceId != null && deviceId.trim().isNotEmpty)
        ? deviceId.trim()
        : null;

    if (isArabic) {
      final buffer = StringBuffer();
      buffer.writeln('السلام عليكم،');
      buffer.writeln('أود الاشتراك في باقة ورقتك برو (Waraqatak Pro):');
      buffer.writeln('• الباقة: $planTitle ($durationText)');
      buffer.writeln('• السعر: $priceStr ج.س');
      if (plan.isFeatured) {
        buffer.writeln('• العرض: وفر 60,000 ج.س (خصم 33% - بمعدل 10,000 ج.س شهرياً)');
      }
      if (cleanDeviceId != null) {
        buffer.writeln('• معرف جهازي: $cleanDeviceId');
      }
      buffer.writeln('');
      buffer.writeln('تطبيق: ورقتك | Waraqatak By Elmahdi Dev');
      buffer.writeln('يرجى تزويدي ببيانات الدفع ومفتاح التفعيل.');
      buffer.write('شكراً لكم!');
      return buffer.toString();
    } else {
      final buffer = StringBuffer();
      buffer.writeln('Hello,');
      buffer.writeln('I would like to subscribe to Waraqatak Pro:');
      buffer.writeln('• Plan: $planTitle ($durationText)');
      buffer.writeln('• Price: $priceStr SDG');
      if (plan.isFeatured) {
        buffer.writeln('• Offer: Save 60,000 SDG (33% OFF - 10,000 SDG/mo)');
      }
      if (cleanDeviceId != null) {
        buffer.writeln('• Device ID: $cleanDeviceId');
      }
      buffer.writeln('');
      buffer.writeln('App: ورقتك | Waraqatak By Elmahdi Dev');
      buffer.writeln('Please provide payment details and the activation key.');
      buffer.write('Thank you!');
      return buffer.toString();
    }
  }

  /// Generates the full WhatsApp HTTPS Uri to open in an external application.
  static Uri generateWhatsAppUri({
    required SubscriptionPlan plan,
    required String planTitle,
    required String durationText,
    String? deviceId,
    bool isArabic = true,
    String? customPhoneNumber,
  }) {
    final phone = customPhoneNumber ?? getSupportWhatsAppNumber();
    final message = generateWhatsAppMessage(
      plan: plan,
      planTitle: planTitle,
      durationText: durationText,
      deviceId: deviceId,
      isArabic: isArabic,
    );
    return Uri.https('wa.me', '/$phone', {'text': message});
  }
}
