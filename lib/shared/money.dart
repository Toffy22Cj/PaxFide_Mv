/// Importes del contrato (referencia-api-v1 §0, develop 1b012da): texto de dígitos (o `long` en el seguimiento) en
/// **unidades mínimas** de la moneda según ISO 4217. COP tiene exponente 2: `"100000"` son 1 000,00 COP.
///
/// Solo se conocen los exponentes que el proyecto usa. Una moneda desconocida no se escala: se muestra el valor en
/// unidades mínimas, dicho así, y no se ofrece donar en ella.
const Map<String, int> _exponents = {'COP': 2};

bool isKnownCurrency(String? currency) => _exponents.containsKey(currency);

/// `1 000,00 COP` (miles con espacio y coma decimal, como el ejemplo del contrato).
String formatMinorUnits(Object amount, String? currency) {
  final text = '$amount'.trim();
  final exp = _exponents[currency];
  if (exp == null) return currency == null ? '$text (unidades mínimas)' : '$text (unidades mínimas de $currency)';
  if (!RegExp(r'^-?[0-9]+$').hasMatch(text)) return '$text $currency';
  final negative = text.startsWith('-');
  final digits = (negative ? text.substring(1) : text).padLeft(exp + 1, '0');
  final whole = digits.substring(0, digits.length - exp).replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final fraction = digits.substring(digits.length - exp);
  final grouped = whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
  return '${negative ? '-' : ''}$grouped${exp > 0 ? ',$fraction' : ''} $currency';
}

/// Lo que escribe el donante (pesos, con `,` o `.` y hasta `exponente` decimales) → texto en unidades mínimas.
/// `null` si no es válido, es cero o la moneda no tiene exponente conocido.
String? toMinorUnits(String input, String? currency) {
  final exp = _exponents[currency];
  if (exp == null) return null;
  final m = RegExp('^([0-9]{1,13})(?:[.,]([0-9]{1,$exp}))?\$').firstMatch(input.trim());
  if (m == null) return null;
  final minor = '${m.group(1)}${(m.group(2) ?? '').padRight(exp, '0')}'.replaceFirst(RegExp(r'^0+'), '');
  return minor.isEmpty ? null : minor;
}
