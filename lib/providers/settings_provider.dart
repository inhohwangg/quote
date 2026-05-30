import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingDone = 'onboarding_complete';

/// Holds the SharedPreferences instance (injected at startup).
final sharedPrefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('Override in ProviderScope'),
);

/// True once the user has completed onboarding.
final onboardingDoneProvider = StateNotifierProvider<OnboardingNotifier, bool>(
  (ref) {
    final prefs = ref.watch(sharedPrefsProvider);
    return OnboardingNotifier(prefs);
  },
);

class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier(this._prefs)
      : super(_prefs.getBool(_kOnboardingDone) ?? false);

  final SharedPreferences _prefs;

  Future<void> complete() async {
    await _prefs.setBool(_kOnboardingDone, true);
    state = true;
  }
}
