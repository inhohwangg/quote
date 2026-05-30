import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

// TODO: Replace with the real product ID registered in Google Play Console.
const premiumProductId = 'premium_no_ads';

/// Wraps [InAppPurchase] and exposes premium state via [isPremiumNotifier].
///
/// Lifecycle:
///   1. Call [initialize] once (in ProviderScope / main).
///   2. Listen to [isPremiumNotifier] for UI updates.
///   3. Call [dispose] when the app lifecycle ends.
class PurchaseService {
  PurchaseService(this._prefs);

  final SharedPreferences _prefs;
  final _iap = InAppPurchase.instance;
  late final StreamSubscription<List<PurchaseDetails>> _sub;

  /// Holds the current premium status; updates fire synchronously on purchase.
  final isPremiumNotifier = ValueNotifier<bool>(false);

  static const _kPremiumKey = 'is_premium';

  Future<void> initialize() async {
    // Restore persisted flag instantly (no network round-trip on cold start).
    isPremiumNotifier.value = _prefs.getBool(_kPremiumKey) ?? false;

    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (_) {}, // Swallow stream errors; don't crash the app.
    );

    // Silently restore any purchases the user completed on another device.
    if (await _iap.isAvailable()) {
      await _iap.restorePurchases();
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      if (p.productID != premiumProductId) continue;

      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        _unlock();
      }

      // Always complete pending purchases to avoid billing library warnings.
      if (p.pendingCompletePurchase) {
        _iap.completePurchase(p);
      }
    }
  }

  void _unlock() {
    _prefs.setBool(_kPremiumKey, true);
    isPremiumNotifier.value = true;
  }

  /// Initiates a non-consumable purchase flow.
  /// Throws [Exception] with a user-readable message on failure.
  Future<void> buyPremium() async {
    if (!await _iap.isAvailable()) {
      throw Exception('인앱 결제를 사용할 수 없는 기기입니다.');
    }

    final response = await _iap.queryProductDetails({premiumProductId});
    if (response.productDetails.isEmpty) {
      throw Exception(
        '상품 정보를 불러오지 못했습니다.\n'
        '(${response.error?.message ?? "Google Play 응답 없음"})',
      );
    }

    final param = PurchaseParam(productDetails: response.productDetails.first);
    // buyNonConsumable is the correct call for a permanent unlock.
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  void dispose() {
    _sub.cancel();
    isPremiumNotifier.dispose();
  }
}
