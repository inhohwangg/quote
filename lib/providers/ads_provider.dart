import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// TODO: Replace with your real ad unit ID from AdMob console before release.
// Current value is Google's official test banner ID — safe for development.
const _testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

/// Loads and holds a single [BannerAd].
/// Returns null when the ad has not loaded yet or failed to load.
/// Disposing the provider automatically disposes the ad (no memory leak).
final bannerAdProvider =
    StateNotifierProvider<BannerAdNotifier, BannerAd?>((ref) {
  final notifier = BannerAdNotifier();
  ref.onDispose(notifier._disposeBanner);
  notifier._load();
  return notifier;
});

class BannerAdNotifier extends StateNotifier<BannerAd?> {
  BannerAdNotifier() : super(null);

  void _load() {
    BannerAd(
      adUnitId: _testBannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) state = ad as BannerAd;
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          // state stays null → widget collapses gracefully
        },
      ),
    ).load();
  }

  void _disposeBanner() {
    state?.dispose();
    state = null;
  }
}
