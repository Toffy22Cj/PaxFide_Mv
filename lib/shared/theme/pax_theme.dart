import 'package:flutter/material.dart';

import 'pax_tokens.dart';

/// Temas de toda la app, con el estilo del diseño de Figma (tarjetas blancas con borde fino, tarjetas destacadas en
/// verde suave, chips de estado, etiquetas encima de los campos).
///
/// El **claro** usa solo la paleta oficial ([PaxTokens]); donde hace falta un tono más suave, un token con
/// transparencia. El **oscuro** es la misma paleta en contraste oscuro ([PaxDarkTokens]): los colores claros pasan a
/// oscuros y viceversa.
abstract final class PaxTheme {
  static final ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: PaxTokens.brandGreen800,
    onPrimary: PaxTokens.white,
    // Tarjeta destacada e indicador de la pestaña: verde-500 suave sobre blanco.
    primaryContainer: PaxTokens.brandGreen500.withValues(alpha: 0.22),
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
    onSurfaceVariant: PaxTokens.brandNeutral700.withValues(alpha: 0.78),
    surfaceContainerLowest: PaxTokens.white,
    surfaceContainerLow: PaxTokens.white,
    surfaceContainer: PaxTokens.white,
    surfaceContainerHigh: PaxTokens.brandGreen50,
    surfaceContainerHighest: PaxTokens.brandGreen50,
    outline: PaxTokens.brandNeutral700.withValues(alpha: 0.55),
    outlineVariant: PaxTokens.brandNeutral700.withValues(alpha: 0.16),
    shadow: PaxTokens.brandNeutral700,
    scrim: PaxTokens.brandNeutral700,
    inverseSurface: PaxTokens.brandGreen900,
    onInverseSurface: PaxTokens.white,
    inversePrimary: PaxTokens.brandGreen50,
    surfaceTint: PaxTokens.brandGreen800,
  );

  /// La misma paleta invertida: botones verde claro, fondos casi negros y tarjetas destacadas en verde-900.
  static final ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: PaxDarkTokens.green,
    onPrimary: PaxTokens.brandGreen900,
    primaryContainer: PaxTokens.brandGreen900,
    onPrimaryContainer: PaxTokens.brandGreen50,
    secondary: PaxDarkTokens.blue,
    onSecondary: PaxDarkTokens.ink,
    secondaryContainer: PaxTokens.brandBlue800,
    onSecondaryContainer: PaxTokens.brandBlue50,
    tertiary: PaxTokens.brandYellow400,
    onTertiary: PaxTokens.brandYellow900,
    tertiaryContainer: PaxTokens.brandYellow900,
    onTertiaryContainer: PaxTokens.brandYellow50,
    error: PaxDarkTokens.danger,
    onError: PaxDarkTokens.background,
    errorContainer: PaxTokens.danger700,
    onErrorContainer: PaxTokens.white,
    surface: PaxDarkTokens.surface,
    onSurface: PaxTokens.brandGreen50,
    onSurfaceVariant: PaxDarkTokens.neutral,
    surfaceContainerLowest: PaxDarkTokens.background,
    surfaceContainerLow: PaxDarkTokens.surface,
    surfaceContainer: PaxDarkTokens.surface,
    surfaceContainerHigh: PaxDarkTokens.surfaceHigh,
    surfaceContainerHighest: PaxDarkTokens.surfaceHigh,
    outline: PaxDarkTokens.neutral.withValues(alpha: 0.6),
    outlineVariant: PaxDarkTokens.neutral.withValues(alpha: 0.18),
    shadow: PaxDarkTokens.background,
    scrim: PaxDarkTokens.background,
    inverseSurface: PaxTokens.brandGreen50,
    onInverseSurface: PaxTokens.brandGreen900,
    inversePrimary: PaxTokens.brandGreen800,
    surfaceTint: PaxDarkTokens.green,
  );

  static final ThemeData light = _build(lightScheme);
  static final ThemeData dark = _build(darkScheme);

  /// Fondo de las pantallas: un gris verdoso muy suave en claro (para que las tarjetas blancas se distingan) y el
  /// verde-50 invertido en oscuro.
  static Color pageBackground(ColorScheme s) => s.brightness == Brightness.dark
      ? PaxDarkTokens.background
      : Color.alphaBlend(PaxTokens.brandNeutral700.withValues(alpha: 0.04), PaxTokens.white);

  static ThemeData _build(ColorScheme s) {
    final page = pageBackground(s);
    final card = BorderRadius.circular(12);
    final control = BorderRadius.circular(8);
    final base = ThemeData(useMaterial3: true, colorScheme: s);
    final text = base.textTheme.apply(bodyColor: s.onSurface, displayColor: s.onSurface);
    return base.copyWith(
      scaffoldBackgroundColor: page,
      textTheme: text.copyWith(
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: s.surface,
        foregroundColor: s.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: s.onSurface),
      ),
      cardTheme: CardThemeData(
        color: s.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: card,
          side: BorderSide(color: s.outlineVariant),
        ),
      ),
      listTileTheme: ListTileThemeData(iconColor: s.primary, textColor: s.onSurface),
      // Etiqueta encima del campo (LabeledField); el campo es blanco (claro) o superficie (oscuro) con borde fino.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: s.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: control,
          borderSide: BorderSide(color: s.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: control,
          borderSide: BorderSide(color: s.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: control,
          borderSide: BorderSide(color: s.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: control,
          borderSide: BorderSide(color: s.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: control,
          borderSide: BorderSide(color: s.error, width: 2),
        ),
        errorStyle: TextStyle(color: s.error),
        helperStyle: TextStyle(color: s.onSurfaceVariant),
        suffixIconColor: s.primary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: s.primary,
          foregroundColor: s.onPrimary,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: control),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: s.primary,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: s.primary),
          shape: RoundedRectangleBorder(borderRadius: control),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: s.primary)),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: s.outlineVariant),
        selectedColor: s.primaryContainer,
        backgroundColor: s.surface,
        labelStyle: TextStyle(color: s.onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: s.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: s.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) =>
              IconThemeData(color: states.contains(WidgetState.selected) ? s.onPrimaryContainer : s.onSurfaceVariant),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            color: states.contains(WidgetState.selected) ? s.primary : s.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: s.surface,
        indicatorColor: s.primaryContainer,
        selectedIconTheme: IconThemeData(color: s.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: s.onSurfaceVariant),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: s.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: s.shadow.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: card,
          side: BorderSide(color: s.outlineVariant),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: page, surfaceTintColor: Colors.transparent),
      dialogTheme: DialogThemeData(backgroundColor: s.surface, surfaceTintColor: Colors.transparent),
      dividerTheme: DividerThemeData(color: s.outlineVariant),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: s.primary,
        linearTrackColor: s.outlineVariant,
        circularTrackColor: s.outlineVariant,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: s.inverseSurface,
        contentTextStyle: TextStyle(color: s.onInverseSurface),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
