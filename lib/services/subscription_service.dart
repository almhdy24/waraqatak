import 'dart:math';

import 'package:elmahdi_api/elmahdi_api.dart';

import '../models/subscription_plan.dart';
import '../utils/marketing_pricing.dart';
import 'license_service.dart';

/// Thin wrapper around the Elmahdi API SDK.
///
/// - Never stores admin tokens or server secrets in the APK.
/// - Idempotency key is generated once and persisted before each order
///   so retries never duplicate orders.
class SubscriptionService {
  SubscriptionService._();

  static const String _appSlug = 'com.elmahdi.waraqatak';

  static ElmahdiApi? _api;

  static ElmahdiApi get _sdk {
    _api ??= ElmahdiApi(appSlug: _appSlug);
    return _api!;
  }

  // ── Products / Plans ───────────────────────────────────────────────────────

  /// Fetches the server product catalogue and converts it to UI plan objects.
  ///
  /// Only active prices for the Waraqatak product are included.
  /// [originalPriceSDG] on each plan is a client-computed marketing reference
  /// price — it is never sent to the backend.
  static Future<List<SubscriptionPlan>> fetchPlans() async {
    final products = await _sdk.products.list();
    return _plansFromProducts(products);
  }

  static List<SubscriptionPlan> _plansFromProducts(List<Product> products) {
    final product = products.where((p) => p.slug == _appSlug).firstOrNull;
    if (product == null) return const [];

    final plans = <SubscriptionPlan>[];

    for (final plan in product.plans) {
      for (final price in plan.prices.where((p) => p.isActive)) {
        final serverAmount = price.priceSdg ?? price.amount;
        final durationType = MarketingPricing.inferFromName(plan.name);
        final refPrice =
            MarketingPricing.referencePrice(serverAmount, durationType);

        plans.add(SubscriptionPlan(
          id: '${plan.id}_${price.id}',
          nameAr: plan.name,
          nameEn: plan.name,
          priceSDG: serverAmount,
          originalPriceSDG: refPrice,
          durationDays: MarketingPricing.daysForType(durationType),
          isMostPopular: false,
          priceId: price.id,
        ));
      }
    }

    // Mark the annual plan as most popular if present.
    final annualIdx = plans.indexWhere(
      (p) =>
          MarketingPricing.inferFromName(p.nameAr) == PlanDurationType.annual,
    );
    if (annualIdx >= 0) {
      plans[annualIdx] = plans[annualIdx].copyWith(isMostPopular: true);
    }

    return plans;
  }

  // ── Payment methods ────────────────────────────────────────────────────────

  static Future<List<PaymentMethod>> getPaymentMethods() =>
      _sdk.paymentMethods.list();

  // ── Orders ─────────────────────────────────────────────────────────────────

  /// Create (or idempotently re-fetch) an order for [priceId].
  ///
  /// [priceId] must be the server Price.id from a [SubscriptionPlan] loaded
  /// via [fetchPlans]. The actual amount is determined server-side from the
  /// price record — the client does not send or modify the amount.
  static Future<CreateOrderResponse> createOrder({
    required int priceId,
    required int paymentMethodId,
    required String buyerName,
    required String buyerContact,
    String? proofNote,
  }) async {
    var ikey = await LicenseService.instance.getSavedIdempotencyKey();
    if (ikey == null) {
      ikey = _generateIdempotencyKey();
      await LicenseService.instance.saveIdempotencyKey(ikey);
    }

    final result = await _sdk.orders.create(
      CreateOrderRequest(
        priceId: priceId,
        paymentMethodId: paymentMethodId,
        buyerName: buyerName,
        buyerContact: buyerContact,
        proofNote: (proofNote?.isEmpty ?? true) ? null : proofNote,
        idempotencyKey: ikey,
      ),
    );

    await LicenseService.instance.setOrderPending(result.reference);
    return result;
  }

  static Future<Order> getOrder(String reference) =>
      _sdk.orders.get(reference);

  // ── License activation ─────────────────────────────────────────────────────

  /// Activate a license obtained from an approved order and persist it locally.
  static Future<ActivateResponse> activateAndStore(
    License license,
    String deviceId,
  ) async {
    final result = await _sdk.licenses.activate(
      licenseKey: license.licenseKey,
      deviceId: deviceId,
    );

    // expiresAt is a String? in the new SDK.
    final expiresAt =
        license.expiresAt != null ? DateTime.tryParse(license.expiresAt!) : null;

    await LicenseService.instance.storeLicense(
      licenseKey: license.licenseKey,
      expiresAt: expiresAt,
      isActive: true,
    );

    return result;
  }

  /// Activate a license by key only — used when the user manually enters their
  /// key after formatting their phone or reinstalling the app.
  static Future<void> activateByKey(String licenseKey, String deviceId) async {
    await _sdk.licenses.activate(
      licenseKey: licenseKey,
      deviceId: deviceId,
    );
    await LicenseService.instance.storeLicense(
      licenseKey: licenseKey,
      expiresAt: null,
      isActive: true,
    );
  }

  /// Re-activate using a stored license key (e.g. after admin resolves a
  /// device-limit issue). Does not store — call [activateAndStore] for that.
  static Future<ActivateResponse> retryActivation(
    String licenseKey,
    String deviceId,
  ) =>
      _sdk.licenses.activate(
        licenseKey: licenseKey,
        deviceId: deviceId,
      );

  // ── App info ───────────────────────────────────────────────────────────────

  static Future<AppVersion> getAppVersion() => _sdk.apps.version();

  static Future<AppConfig> getAppConfig() => _sdk.apps.config();

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  static void close() {
    _api?.dispose();
    _api = null;
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  static String _generateIdempotencyKey() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
