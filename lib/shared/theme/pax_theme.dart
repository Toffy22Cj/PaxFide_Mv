import 'package:flutter/material.dart';

import 'pax_tokens.dart';

/// Temas claro y oscuro de toda la app, construidos solo con [PaxTokens]. Donde hace falta un tono más suave se usa
/// un token con transparencia, nunca un color nuevo.
///
/// La paleta oficial no tiene fondos oscuros neutros: el modo oscuro usa el verde más oscuro de la marca
/// (`brand-green-900`) como fondo y `brand-green-800` / `brand-neutral-700` para las superficies elevadas.
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

  static final ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: PaxTokens.brandGreen50,
    onPrimary: PaxTokens.brandGreen900,
    primaryContainer: PaxTokens.brandGreen800,
    onPrimaryContainer: PaxTokens.white,
    secondary: PaxTokens.brandBlue50,
    onSecondary: PaxTokens.brandBlue800,
    secondaryContainer: PaxTokens.brandBlue800,
    onSecondaryContainer: PaxTokens.white,
    tertiary: PaxTokens.brandYellow400,
    onTertiary: PaxTokens.brandYellow900,
    tertiaryContainer: PaxTokens.brandYellow900,
    onTertiaryContainer: PaxTokens.brandYellow50,
    error: PaxTokens.danger700,
    onError: PaxTokens.white,
    errorContainer: PaxTokens.danger700,
    onErrorContainer: PaxTokens.white,
    surface: PaxTokens.brandGreen900,
    onSurface: PaxTokens.white,
    onSurfaceVariant: PaxTokens.brandGreen50,
    surfaceContainerLowest: PaxTokens.brandGreen900,
    surfaceContainerLow: PaxTokens.brandGreen900,
    surfaceContainer: PaxTokens.brandGreen800,
    surfaceContainerHigh: PaxTokens.brandGreen800,
    surfaceContainerHighest: PaxTokens.brandNeutral700,
    outline: PaxTokens.brandGreen50.withValues(alpha: 0.5),
    outlineVariant: PaxTokens.white.withValues(alpha: 0.15),
    shadow: PaxTokens.brandGreen900,
    scrim: PaxTokens.brandGreen900,
    inverseSurface: PaxTokens.brandGreen50,
    onInverseSurface: PaxTokens.brandGreen900,
    inversePrimary: PaxTokens.brandGreen800,
    surfaceTint: PaxTokens.brandGreen50,
  );

  static final ThemeData light = _build(lightScheme);
  static final ThemeData dark = _build(darkScheme);

  static ThemeData _build(ColorScheme s) {
    final dark = s.brightness == Brightness.dark;
    final radius = BorderRadius.circular(12);
    // Sobre el fondo oscuro, danger-700 no se lee como texto: el mensaje de error del campo va en blanco y el borde
    // en danger-700. Los avisos de error de las pantallas usan ErrorMessage (fondo danger-700, texto blanco).
    final errorText = dark ? PaxTokens.white : PaxTokens.danger700;
    final indicator = dark ? PaxTokens.brandBlue800 : PaxTokens.brandGreen800;
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
          borderSide: const BorderSide(color: PaxTokens.danger700, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: PaxTokens.danger700, width: 2),
        ),
        errorStyle: TextStyle(color: errorText),
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
