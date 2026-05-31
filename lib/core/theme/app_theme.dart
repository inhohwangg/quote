import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Color(0xFF4A90D9);

  // ── 라이트 테마 ──────────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        fontFamily: 'PretendardGOV',
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A1A1A),
          surfaceTintColor: Colors.transparent,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
        ),
        dividerColor: const Color(0xFFE8EDF5),
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
        ),
      );

  // ── 다크 테마 ────────────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        fontFamily: 'PretendardGOV',
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Color(0xFF1C1C28),
          foregroundColor: Color(0xFFE8E8F0),
          surfaceTintColor: Colors.transparent,
        ),
        scaffoldBackgroundColor: const Color(0xFF12121E),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          color: const Color(0xFF1C1C28),
        ),
        dividerColor: const Color(0xFF2A2A3E),
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
        ),
      );
}
