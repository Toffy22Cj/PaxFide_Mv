import 'package:flutter/material.dart';

import 'pax_tokens.dart';

/// Temas de toda la app. El **claro** usa solo la paleta oficial ([PaxTokens]); donde hace falta un tono más suave, un
/// token con transparencia, nunca un color nuevo. El **oscuro** es oscuro de verdad ([PaxDarkTokens]): grises casi
/// negros y la marca solo como acento.
abstract final class PaxTheme {
  static final ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: PaxTokens.brandGreen800,
    onPrimary: PaxTokens.white,
    primaryContainer: PaxTokens.brandGreen50,
    onPrimaryContainer: PaxTokens.brandGreen900,
    secondary: PaxTokens.brandBlue700,
    onSecondary: PaxTokens.white,
    secondaryContainer: PaxTokens.brandBlue50,
    onSecondaryContainer: PaxTokens.brandBlue800,
    tertiary: PaxTokens.brandYellow400,
    onTertiary: PaxTokens.brandYellow900,
    tertiaryContainer: PaxTokens.brandYellow50,
    onTertiaryContainer: PaxTokens.brandYellow900,
    error: PaxTokens.danger700,
    onError: PaxTokens.white,
    errorContainer: PaxTokens.danger700,
    onErrorContainer: PaxTokens.white,
    surface: PaxTokens.white,
    onSurface: PaxTokens.brandNeutral700,
    onSurfaceVariant: PaxTokens.brandNeutral700.withValues(alpha: 0.8),
    surfaceContainerLowest: PaxTokens.white,
    surfaceContainerLow: PaxTokens.white,
    surfaceContainer: PaxTokens.brandGreen50,
    surfaceContainerHigh: PaxTokens.brandGreen50,
    surfaceContainerHighest: PaxTokens.brandBlue50,
    outline: PaxTokens.brandNeutral700.withValues(alpha: 0.5),
    outlineVariant: PaxTokens.brandNeutral700.withValues(alpha: 0.2),
    shadow: PaxTokens.brandNeutral700,
    scrim: PaxTokens.brandNeutral700,
    inverseSurface: PaxTokens.brandGreen900,
    onInverseSurface: PaxTokens.white,
    inversePrimary: PaxTokens.brandGreen50,
    surfaceTint: PaxTokens.brandGreen800,
  );

  /// Modo oscuro: grises casi negros ([PaxDarkTokens]); la marca solo como acento. El amarillo oficial se lee bien
  /// sobre negro y se usa tal cual.
  static final ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: PaxDarkTokens.green,
    onPrimary: PaxDarkTokens.onGreen,
    primaryContainer: PaxDarkTokens.greenContainer,
    onPrimaryContainer: PaxDarkTokens.onGreenContainer,
    secondary: PaxDarkTokens.blue,
    onSecondary: PaxDarkTokens.onBlue,
    secondaryContainer: PaxDarkTokens.blueContainer,
    onSecondaryContainer: PaxDarkTokens.onBlueContainer,
    tertiary: PaxTokens.brandYellow400,
    onTertiary: PaxTokens.brandYellow900,
    tertiaryContainer: PaxDarkTokens.yellowContainer,
    onTertiaryContainer: PaxDarkTokens.onYellowContainer,
    error: PaxDarkTokens.error,
    onError: PaxDarkTokens.onError,
    errorContainer: PaxDarkTokens.errorContainer,
    onErrorContainer: PaxDarkTokens.onErrorContainer,
    surface: PaxDarkTokens.background,
    onSurface: PaxDarkTokens.text,
    onSurfaceVariant: PaxDarkTokens.textMuted,
    surfaceContainerLowest: PaxDarkTokens.background,
    surfaceContainerLow: PaxDarkTokens.surface,
    surfaceContainer: PaxDarkTokens.surface,
    surfaceContainerHigh: PaxDarkTokens.surfaceHigh,
    surfaceContainerHighest: PaxDarkTokens.surfaceHighest,
    outline: PaxDarkTokens.outline,
    outlineVariant: PaxDarkTokens.outlineVariant,
    shadow: PaxDarkTokens.background,
    scrim: PaxDarkTokens.background,
    inverseSurface: PaxDarkTokens.text,
    onInverseSurface: PaxDarkTokens.background,
    inversePrimary: PaxTokens.brandGreen800,
    surfaceTint: PaxDarkTokens.green,
  );

  static final ThemeData light = _build(lightScheme);
  static final ThemeData dark = _build(darkScheme);

  static ThemeData _build(ColorScheme s) {
    final dark = s.brightness == Brightness.dark;
    final radius = BorderRadius.circular(12);
    // Pestaña elegida: brand-green-800 (claro) o el verde oscuro de acento (oscuro), siempre con ícono blanco.
    final indicator = dark ? PaxDarkTokens.greenContainer : PaxTokens.brandGreen800;
    return ThemeData(
      useMaterial3: true,
      colorScheme: s,
      scaffoldBackgroundColor: s.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: s.surface,
        foregroundColor: s.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        color: s.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: s.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: s.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: s.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: s.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: s.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: s.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: s.error, width: 2),
        ),
        errorStyle: TextStyle(color: s.error),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: s.primary,
          foregroundColor: s.onPrimary,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: s.primary,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: s.outline),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: dark ? s.primary : s.secondary),
      ),
      // Pestaña elegida bien visible: indicador brand-green-800 (claro) o brand-blue-800 (oscuro), ícono en blanco.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: s.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: indicator,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(color: states.contains(WidgetState.selected) ? PaxTokens.white : s.onSurface),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: s.surface,
        indicatorColor: indicator,
        selectedIconTheme: const IconThemeData(color: PaxTokens.white),
        unselectedIconTheme: IconThemeData(color: s.onSurface),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: dark ? s.surfaceContainer : s.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: s.shadow.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: s.outlineVariant),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: s.surface, surfaceTintColor: Colors.transparent),
      dialogTheme: DialogThemeData(backgroundColor: s.surface, surfaceTintColor: Colors.transparent),
      dividerTheme: DividerThemeData(color: s.outlineVariant),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: dark ? s.primary : s.secondary),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: s.inverseSurface,
        contentTextStyle: TextStyle(color: s.onInverseSurface),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
