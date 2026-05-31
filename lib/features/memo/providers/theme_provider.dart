import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 앱 전역 ThemeMode 관리 Provider
final themeModeProvider =
    StateNotifierProvider<_ThemeModeNotifier, ThemeMode>(
  (_) => _ThemeModeNotifier(),
);

class _ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _key = 'isDarkMode';

  _ThemeModeNotifier() : super(ThemeMode.light) {
    _restore(); // 앱 재시작 시 이전 설정 복원
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_key) == true) state = ThemeMode.dark;
  }

  Future<void> toggle() async {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state == ThemeMode.dark);
  }

  bool get isDark => state == ThemeMode.dark;
}
