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

/// Colores del **modo oscuro**: la **misma paleta** llevada a contraste oscuro. Cada color es un token oficial con su
/// luminosidad invertida (HSL: mismo tono y saturación, `L → 1 − L`), así el verde-800 de los botones pasa a un verde
/// claro y el verde-50 de los fondos pasa a casi negro. Los fondos de tarjetas y chips son, a la inversa, los tonos
/// oscuros de la paleta tal cual (verde-900, azul-800, amarillo-900, danger-700). Lo comprueba
/// `test/architecture/design_tokens_test.dart`.
abstract final class PaxDarkTokens {
  // Fondos: brand-green-50 invertido, y dos pasos un poco más claros para superficies y campos.
  static const Color background = Color(0xFF09110A); // inverso de brand-green-50
  static const Color surface = Color(0xFF111A15);
  static const Color surfaceHigh = Color(0xFF19241E);

  // Texto y bordes: brand-neutral-700 invertido.
  static const Color neutral = Color(0xFFA9BFBF); // inverso de brand-neutral-700

  // Acentos: los tonos 800/700/400 invertidos.
  static const Color green = Color(0xFF9FDFCB); // inverso de brand-green-800
  static const Color greenStrong = Color(0xFFAEE4D4); // inverso de brand-green-900
  static const Color blue = Color(0xFF5DA8CD); // inverso de brand-blue-700
  static const Color blueStrong = Color(0xFF86BFDA); // inverso de brand-blue-800
  static const Color yellow = Color(0xFFF7CF87); // inverso de brand-yellow-900
  static const Color danger = Color(0xFFE7564B); // inverso de danger-700
  static const Color ink = Color(0xFF061014); // inverso de brand-blue-50 (texto sobre acentos)

  /// Pares (token oficial → su inverso) que deben cumplir la regla `L → 1 − L`.
  static const List<(Color, Color)> inverseOf = [
    (PaxTokens.brandGreen50, background),
    (PaxTokens.brandNeutral700, neutral),
    (PaxTokens.brandGreen800, green),
    (PaxTokens.brandGreen900, greenStrong),
    (PaxTokens.brandBlue700, blue),
    (PaxTokens.brandBlue800, blueStrong),
    (PaxTokens.brandYellow900, yellow),
    (PaxTokens.danger700, danger),
    (PaxTokens.brandBlue50, ink),
  ];

  static const Map<String, Color> all = {
    'background': background,
    'surface': surface,
    'surfaceHigh': surfaceHigh,
    'neutral': neutral,
    'green': green,
    'greenStrong': greenStrong,
    'blue': blue,
    'blueStrong': blueStrong,
    'yellow': yellow,
    'danger': danger,
    'ink': ink,
  };
}
