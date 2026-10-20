import 'package:flutter/painting.dart';

/// Paleta oficial de PaxFide, la del **modo claro**. Este archivo es el **único** lugar de la app donde se escribe un
/// color (aquí y en [PaxDarkTokens]): el resto lo toma del tema (`Theme.of(context).colorScheme`). Lo vigila
/// `test/architecture/design_tokens_test.dart`.
abstract final class PaxTokens {
  static const Color brandGreen900 = Color(0xFF1B5141);
  static const Color brandGreen800 = Color(0xFF20604C);
  static const Color brandGreen500 = Color(0xFF4E9155);
  static const Color brandGreen50 = Color(0xFFEEF6EF);

  static const Color brandBlue800 = Color(0xFF255E79);
  static const Color brandBlue700 = Color(0xFF327DA2);
  static const Color brandBlue500 = Color(0xFF3688B0);
  static const Color brandBlue50 = Color(0xFFEBF5F9);

  static const Color brandYellow900 = Color(0xFF785008);
  static const Color brandYellow400 = Color(0xFFF3B544);
  static const Color brandYellow50 = Color(0xFFFDF4E2);

  static const Color brandNeutral700 = Color(0xFF405656);
  static const Color white = Color(0xFFFFFFFF);
  static const Color danger700 = Color(0xFFB42318);

  /// Los 14 tokens con su nombre oficial.
  static const Map<String, Color> all = {
    'brand-green-900': brandGreen900,
    'brand-green-800': brandGreen800,
    'brand-green-500': brandGreen500,
    'brand-green-50': brandGreen50,
    'brand-blue-800': brandBlue800,
    'brand-blue-700': brandBlue700,
    'brand-blue-500': brandBlue500,
    'brand-blue-50': brandBlue50,
    'brand-yellow-900': brandYellow900,
    'brand-yellow-400': brandYellow400,
    'brand-yellow-50': brandYellow50,
    'brand-neutral-700': brandNeutral700,
    'white': white,
    'danger-700': danger700,
  };
}

/// Colores del **modo oscuro**. No son de la paleta oficial, que es del modo claro: el modo oscuro tiene que ser
/// oscuro (grises casi negros, sin fondo verde). Los colores de marca aparecen solo como acentos, aclarados lo justo
/// para leerse sobre negro.
abstract final class PaxDarkTokens {
  // Fondo y superficies: grises neutros, de más oscuro a más claro.
  static const Color background = Color(0xFF121417);
  static const Color surface = Color(0xFF1B1E22);
  static const Color surfaceHigh = Color(0xFF23272C);
  static const Color surfaceHighest = Color(0xFF2C3137);
  static const Color outline = Color(0xFF5C636B);
  static const Color outlineVariant = Color(0xFF33383E);

  // Texto.
  static const Color text = Color(0xFFE6E8EB);
  static const Color textMuted = Color(0xFFA8AFB7);

  // Acentos de marca aclarados (verde, azul) y sus fondos.
  static const Color green = Color(0xFF8CCB94);
  static const Color onGreen = Color(0xFF0E2A16);
  static const Color greenContainer = Color(0xFF27402D);
  static const Color onGreenContainer = Color(0xFFCDEBD1);
  static const Color blue = Color(0xFF8CC8E3);
  static const Color onBlue = Color(0xFF0B2B3A);
  static const Color blueContainer = Color(0xFF1E3A4A);
  static const Color onBlueContainer = Color(0xFFCFE8F4);
  static const Color yellowContainer = Color(0xFF3D2E0F);
  static const Color onYellowContainer = Color(0xFFFBE3B5);

  // Error: rojo claro para texto y un fondo rojo oscuro para los avisos.
  static const Color error = Color(0xFFFF8A7A);
  static const Color onError = Color(0xFF3B0A05);
  static const Color errorContainer = Color(0xFF5A1610);
  static const Color onErrorContainer = Color(0xFFFFDAD5);

  static const Map<String, Color> all = {
    'background': background,
    'surface': surface,
    'surfaceHigh': surfaceHigh,
    'surfaceHighest': surfaceHighest,
    'outline': outline,
    'outlineVariant': outlineVariant,
    'text': text,
    'textMuted': textMuted,
    'green': green,
    'onGreen': onGreen,
    'greenContainer': greenContainer,
    'onGreenContainer': onGreenContainer,
    'blue': blue,
    'onBlue': onBlue,
    'blueContainer': blueContainer,
    'onBlueContainer': onBlueContainer,
    'yellowContainer': yellowContainer,
    'onYellowContainer': onYellowContainer,
    'error': error,
    'onError': onError,
    'errorContainer': errorContainer,
    'onErrorContainer': onErrorContainer,
  };
}
