import 'package:flutter/material.dart';

const brandBlue = Color(0xFF0756E8);
const brandCyan = Color(0xFF00BEF5);
const brandNavy = Color(0xFF0C1936);


/// Preset tampilan. Bisa diganti tanpa mengubah tema terang/gelap.
const appTemplates = <String>[
  'Biru Orbit', 'Midnight', 'Emerald', 'Sunset',
  'Ocean', 'Rose Quartz', 'Graphite', 'Golden',
];

/// Global notifier applies the chosen system font immediately across MaterialApp.
/// Fonts are Android system families: no external font download is required.
final ValueNotifier<String> aganFontFamily = ValueNotifier<String>('Roboto');
const appFontChoices = <String, String>{
  'Roboto': 'Roboto · Standar',
  'sans-serif': 'Sans Serif · Clean',
  'sans-serif-medium': 'Sans Medium · Modern',
  'sans-serif-condensed': 'Condensed · Ringkas',
  'serif': 'Serif · Elegan',
  'monospace': 'Monospace · Teknologi',
};
Color templateAccent(String name) {
  switch (name) {
    case 'Midnight': return const Color(0xFF5368E7);
    case 'Emerald': return const Color(0xFF008D78);
    case 'Sunset': return const Color(0xFFDC643A);
    case 'Ocean': return const Color(0xFF057CB6);
    case 'Rose Quartz': return const Color(0xFFB43C83);
    case 'Graphite': return const Color(0xFF454B5A);
    case 'Golden': return const Color(0xFFA36D12);
    default: return brandBlue;
  }
}
List<Color> templateGradient(String name) {
  switch (name) {
    case 'Midnight': return const [Color(0xFF191953), Color(0xFF3843A4), Color(0xFF7671E6)];
    case 'Emerald': return const [Color(0xFF074D52), Color(0xFF087E79), Color(0xFF0FBDA2)];
    case 'Sunset': return const [Color(0xFF7A2959), Color(0xFFCA4C51), Color(0xFFF7A44B)];
    case 'Ocean': return const [Color(0xFF084A79), Color(0xFF087DAC), Color(0xFF15B2D1)];
    case 'Rose Quartz': return const [Color(0xFF79315E), Color(0xFFB5418B), Color(0xFFE88CB9)];
    case 'Graphite': return const [Color(0xFF252B39), Color(0xFF46536B), Color(0xFF78859B)];
    case 'Golden': return const [Color(0xFF6C4511), Color(0xFFA97720), Color(0xFFF3BF59)];
    default: return const [Color(0xFF052B8C), Color(0xFF075FD4), Color(0xFF02A0F0)];
  }
}

/// Theme roles deliberately use contrasting foreground/background colors.
/// Never use white text on a regular surface; reserve white for brand gradients.
ThemeData aganTheme(Brightness brightness, {String template = 'Biru Orbit'}) {
  final dark = brightness == Brightness.dark;
  final background = dark ? const Color(0xFF0D1522) : const Color(0xFFF5F8FD);
  final surface = dark ? const Color(0xFF192538) : Colors.white;
  final foreground = dark ? const Color(0xFFF1F5FC) : const Color(0xFF17253B);
  final muted = dark ? const Color(0xFFC0CDDE) : const Color(0xFF52647B);
  final outline = dark ? const Color(0xFF40516A) : const Color(0xFFDDE6F2);

  final scheme = ColorScheme.fromSeed(
    seedColor: templateAccent(template),
    brightness: brightness,
  ).copyWith(
    primary: dark ? Color.lerp(templateAccent(template), Colors.white, .42)! : templateAccent(template),
    onPrimary: dark ? const Color(0xFF062251) : Colors.white,
    surface: surface,
    onSurface: foreground,
    onSurfaceVariant: muted,
    outlineVariant: outline,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
  );
  final type = base.textTheme
      .apply(fontFamily: aganFontFamily.value, bodyColor: foreground, displayColor: foreground)
      .copyWith(
        headlineSmall: TextStyle(color: foreground, fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -.7),
        titleLarge: TextStyle(color: foreground, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.45),
        titleMedium: TextStyle(color: foreground, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -.2),
        titleSmall: TextStyle(color: foreground, fontSize: 14, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: foreground, fontSize: 15.5, height: 1.42),
        bodyMedium: TextStyle(color: foreground, fontSize: 13.5, height: 1.45),
        bodySmall: TextStyle(color: muted, fontSize: 12, height: 1.4),
        labelLarge: TextStyle(color: foreground, fontSize: 13.5, fontWeight: FontWeight.w800),
        labelMedium: TextStyle(color: muted, fontSize: 11.5, fontWeight: FontWeight.w700),
      );

  return base.copyWith(
    scaffoldBackgroundColor: background,
    textTheme: type,
    primaryTextTheme: type,
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      margin: EdgeInsets.zero,
    ),
    listTileTheme: ListTileThemeData(
      textColor: foreground,
      iconColor: muted,
      titleTextStyle: TextStyle(color: foreground, fontWeight: FontWeight.w800, fontSize: 14,
        fontFamily: aganFontFamily.value),
      subtitleTextStyle: TextStyle(color: muted, fontSize: 12, height: 1.4,
        fontFamily: aganFontFamily.value),
    ),
    dividerTheme: DividerThemeData(color: outline.withValues(alpha: .8), thickness: .8),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF222F42) : Colors.white,
      labelStyle: TextStyle(color: muted),
      hintStyle: TextStyle(color: muted),
      floatingLabelStyle: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: outline),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: foreground,
      scrolledUnderElevation: 0,
      centerTitle: false,
      elevation: 0,
      titleTextStyle: TextStyle(color: foreground, fontSize: 19, fontWeight: FontWeight.w900,
        fontFamily: aganFontFamily.value),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: scheme.primary.withValues(alpha: .13),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
        color: states.contains(WidgetState.selected) ? scheme.primary : muted,
        fontSize: 11,
        fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
      )),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? scheme.onPrimary : null),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? scheme.primary : null),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
  );
}
