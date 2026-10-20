import 'package:flutter/painting.dart';

/// Paleta oficial de PaxFide. Es el **único** lugar de la app donde se escribe un color: el resto lo toma del tema
/// (`Theme.of(context).colorScheme`) o, si hace falta un color de marca concreto, de aquí. Lo vigila
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
