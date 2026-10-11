/// Importes del contrato (referencia-api-v1 §0): texto de dígitos (o `long` en el seguimiento) en **unidades
/// mínimas** de la moneda según ISO 4217. COP tiene exponente 2: `"100000"` son $1.000 COP.
///
/// Solo se conocen los exponentes que el proyecto usa. Una moneda desconocida no se escala: se muestra el valor en
/// unidades mínimas, dicho así, y no se ofrece donar en ella.
const Map<String, int> _exponents = {'COP': 2};

bool isKnownCurrency(String? currency) => _exponents.containsKey(currency);

/// `$1.000.000 COP` (formato colombiano: puntos de miles y coma decimal solo
/// si hay centavos).
String formatMinorUnits(Object amount, String? currency) {
  final text = '$amount'.trim();
  final exp = _exponents[currency];
  if (exp == null) return currency == null ? '$text (unidades mínimas)' : '$text (unidades mínimas de $currency)';
  if (!RegExp(r'^-?[0-9]+$').hasMatch(text)) return '$text $currency';
  final negative = text.startsWith('-');
  final digits = (negative ? text.substring(1) : text).padLeft(exp + 1, '0');
  final whole = digits.substring(0, digits.length - exp).replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final fraction = digits.substring(digits.length - exp);
  final grouped = whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  final cents = exp > 0 && RegExp(r'[1-9]').hasMatch(fraction) ? ',$fraction' : '';
  return '${negative ? '-' : ''}\$$grouped$cents $currency';
}

/// Lo que escribe el donante → texto en unidades mínimas. Acepta pesos con
/// puntos de miles (`1.000.000`), `$` y espacios, y hasta `exponente`
/// decimales con coma (`1000,50`) o punto (`1000.50`). `null` si no es válido,
/// es cero o la moneda no tiene exponente conocido.
String? toMinorUnits(String input, String? currency) {
  final exp = _exponents[currency];
  if (exp == null) return null;
  var text = input.replaceAll(RegExp(r'[\s$]'), '');
  // Puntos de miles: 1.000.000 o 1.000.000,50
  if (RegExp(r'^[0-9]{1,3}(\.[0-9]{3})+(,[0-9]+)?$').hasMatch(text)) text = text.replaceAll('.', '');
  final m = RegExp('^([0-9]{1,13})(?:[.,]([0-9]{1,$exp}))?\$').firstMatch(text);
  if (m == null) return null;
  final minor = '${m.group(1)}${(m.group(2) ?? '').padRight(exp, '0')}'.replaceFirst(RegExp(r'^0+'), '');
  return minor.isEmpty ? null : minor;
}

/// Versión corta para los ejes de los gráficos: `$1,4 M`, `$500 mil`, `$800`. Los textos usan [formatMinorUnits].
String formatCompact(num minorUnits, String? currency) {
  final exp = _exponents[currency] ?? 0;
  final major = minorUnits / _pow10(exp);
  String trim(double v) {
    final s = v >= 10 || v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
    return s.replaceAll('.', ',');
  }

  if (major.abs() >= 1000000) return '\$${trim(major / 1000000)} M';
  if (major.abs() >= 1000) return '\$${trim(major / 1000)} mil';
  return '\$${major.round()}';
}

num _pow10(int exp) {
  var r = 1;
  for (var i = 0; i < exp; i++) {
    r *= 10;
  }
  return r;
}

/// Redondea un importe en unidades mínimas a unidades enteras de la moneda (pesos sin centavos).
int roundToWholeUnits(num minorUnits, String? currency) {
  final unit = _pow10(_exponents[currency] ?? 0);
  return (minorUnits / unit).round() * unit.toInt();
}
