import 'package:flutter/material.dart';

class KidsZoneColors {
  static const ocean = Color(0xFF0B7285);
  static const sky = Color(0xFF2F80ED);
  static const leaf = Color(0xFF2FA66A);
  static const sun = Color(0xFFF4B942);
  static const ink = Color(0xFF162033);
  static const mist = Color(0xFFF4F8FB);
  static const field = Color(0xFFFFFFFF);
  static const line = Color(0xFFD8E2EA);
}

ThemeData buildKidsZoneTheme() {
  const seed = KidsZoneColors.ocean;
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Roboto',
  );
  final textTheme = base.textTheme.apply(
    bodyColor: KidsZoneColors.ink,
    displayColor: KidsZoneColors.ink,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: KidsZoneColors.mist,
    textTheme: textTheme.copyWith(
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      headlineSmall: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      bodyLarge: textTheme.bodyLarge?.copyWith(
        height: 1.35,
        letterSpacing: 0,
      ),
      labelLarge: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: KidsZoneColors.mist,
      foregroundColor: KidsZoneColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KidsZoneColors.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIconColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.focused)) return KidsZoneColors.sky;
        return KidsZoneColors.ocean;
      }),
      labelStyle: const TextStyle(
        color: Color(0xFF5C6B7A),
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF8795A3),
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: KidsZoneColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: KidsZoneColors.sky, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error, width: 1.8),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KidsZoneColors.sky,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const BorderSide(color: KidsZoneColors.sky);
          }
          return const BorderSide(color: KidsZoneColors.line);
        }),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: KidsZoneColors.field,
      indicatorColor: KidsZoneColors.sky.withValues(alpha: 0.13),
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
  );
}
