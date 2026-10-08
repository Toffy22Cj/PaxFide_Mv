import 'package:flutter/material.dart';

/// Verde de acento de PaxFide.
const Color paxAccent = Color(0xFF10B981);

/// Verde de marca (botones principales en modo claro).
const Color paxBrand = Color(0xFF1E4A38);

/// Colores de la app en modo oscuro o claro. Es el diseño del inicio y lo
/// usan todas las pantallas, para que la app se vea como una sola.
@immutable
class PaxPalette extends ThemeExtension<PaxPalette> {
  const PaxPalette({
    required this.dark,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.textMuted,
  });

  final bool dark;
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color text;
  final Color textMuted;

  static const PaxPalette darkPalette = PaxPalette(
    dark: true,
    bg: Color(0xFF070B0E),
    surface: Color(0xFF0F151D),
    surfaceAlt: Color(0xFF16202C),
    border: Color(0xFF1F2D3D),
    text: Color(0xFFF8FAFC),
    textMuted: Color(0xFF7E92A7),
  );

  static const PaxPalette lightPalette = PaxPalette(
    dark: false,
    bg: Color(0xFFF1F5F9),
    surface: Colors.white,
    surfaceAlt: Color(0xFFF8FAFC),
    border: Color(0xFFE2E8F0),
    text: Color(0xFF0F172A),
    textMuted: Color(0xFF64748B),
  );

  static PaxPalette of(BuildContext context) =>
      Theme.of(context).extension<PaxPalette>() ?? darkPalette;

  @override
  PaxPalette copyWith() => this;

  @override
  PaxPalette lerp(ThemeExtension<PaxPalette>? other, double t) =>
      other is PaxPalette && t >= 0.5 ? other : this;
}

/// Tema de toda la app a partir de la paleta.
ThemeData paxTheme({required bool dark}) {
  final p = dark ? PaxPalette.darkPalette : PaxPalette.lightPalette;
  final primary = dark ? paxAccent : paxBrand;
  final scheme = ColorScheme.fromSeed(
    seedColor: paxAccent,
    brightness: dark ? Brightness.dark : Brightness.light,
  ).copyWith(
    primary: primary,
    onPrimary: Colors.white,
    surface: p.surface,
    onSurface: p.text,
    onSurfaceVariant: p.textMuted,
    outline: p.border,
    outlineVariant: p.border,
    surfaceContainerHighest: p.surfaceAlt,
  );
  final radius = BorderRadius.circular(14);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    extensions: [p],
    appBarTheme: AppBarTheme(
      backgroundColor: p.surface,
      surfaceTintColor: p.surface,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.text),
      shape: Border(bottom: BorderSide(color: p.border)),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      surfaceTintColor: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: p.border)),
    ),
    dividerTheme: DividerThemeData(color: p.border, space: 24),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceAlt,
      labelStyle: TextStyle(color: p.textMuted),
      hintStyle: TextStyle(color: p.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.border)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.border)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: paxAccent, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        minimumSize: const Size(0, 46),
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: paxAccent)),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.surface, surfaceTintColor: p.surface),
    dialogTheme: DialogThemeData(backgroundColor: p.surface, surfaceTintColor: p.surface),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: paxAccent, linearTrackColor: p.surfaceAlt),
    listTileTheme: ListTileThemeData(iconColor: p.textMuted, textColor: p.text),
  );
}
