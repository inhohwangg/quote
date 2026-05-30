import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_provider.dart';
import '../services/purchase_service.dart';

// ---------------------------------------------------------------------------
// Service provider — single instance, disposed with the ProviderScope.
// ---------------------------------------------------------------------------

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final prefs = ref.read(sharedPrefsProvider);
  final service = PurchaseService(prefs);
  ref.onDispose(service.dispose);
  return service;
});

// ---------------------------------------------------------------------------
// Premium state — bridges PurchaseService.isPremiumNotifier → Riverpod.
// ---------------------------------------------------------------------------

final isPremiumProvider =
    StateNotifierProvider<PremiumNotifier, bool>((ref) {
  final service = ref.watch(purchaseServiceProvider);
  return PremiumNotifier(service);
});

class PremiumNotifier extends StateNotifier<bool> {
  PremiumNotifier(this._service) : super(false) {
    _init();
  }

  final PurchaseService _service;
  VoidCallback? _listener;

  Future<void> _init() async {
    await _service.initialize();

    // Mirror ValueNotifier into Riverpod state.
    _listener = () {
      if (mounted) state = _service.isPremiumNotifier.value;
    };
    _service.isPremiumNotifier.addListener(_listener!);
    if (mounted) state = _service.isPremiumNotifier.value;
  }

  @override
  void dispose() {
    if (_listener != null) {
      _service.isPremiumNotifier.removeListener(_listener!);
    }
    super.dispose();
  }

  /// Triggers the Google Play purchase flow.
  Future<void> buy() => _service.buyPremium();
}
