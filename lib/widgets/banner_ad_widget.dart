import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../providers/ads_provider.dart';
import '../providers/purchase_provider.dart';

/// Renders an AdMob banner at the bottom of the screen.
/// Collapses to zero height when:
///   - The user is premium (ad-free).
///   - The ad has not yet loaded or failed to load.
///
/// Using [AnimatedSize] is intentionally avoided here — instant collapse is
/// preferable on old devices (avoids jank from size animations).
class BannerAdWidget extends ConsumerWidget {
  const BannerAdWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Premium check first — avoids even reading the ad state.
    if (ref.watch(isPremiumProvider)) return const SizedBox.shrink();

    final ad = ref.watch(bannerAdProvider);
    if (ad == null) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: SizedBox(
        height: ad.size.height.toDouble(),
        width: double.infinity,
        child: AdWidget(ad: ad),
      ),
    );
  }
}
