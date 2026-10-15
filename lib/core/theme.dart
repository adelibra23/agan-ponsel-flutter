import 'package:flutter/material.dart';

const brandBlue = Color(0xFF0756E8);
const brandCyan = Color(0xFF00BEF5);
const brandNavy = Color(0xFF0C1936);

ThemeData aganTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: brandBlue,
    brightness: brightness,
    surface: dark ? const Color(0xFF151D2B) : Colors.white,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  return base.copyWith(
    scaffoldBackgroundColor: dark ? const Color(0xFF0C111D) : const Color(0xFFF5F8FD),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xFF192232) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF202B3A) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: dark ? const Color(0xFF3C4655) : const Color(0xFFE0E7F2)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF151D2B) : Colors.white,
      foregroundColor: dark ? Colors.white : brandNavy,
      scrolledUnderElevation: 0,
      centerTitle: false,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF151D2B) : Colors.white,
      indicatorColor: brandBlue.withOpacity(.12),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    textTheme: base.textTheme.apply(fontFamily: 'Roboto').copyWith(
      headlineSmall: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -.7),
      titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.5),
      titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -.22),
      titleSmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -.1),
      bodyLarge: const TextStyle(fontSize: 15.5, height: 1.42, letterSpacing: -.1),
      bodyMedium: const TextStyle(fontSize: 13.5, height: 1.45, letterSpacing: -.1),
      labelLarge: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: 0),
      labelMedium: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
    ),
  );
}
