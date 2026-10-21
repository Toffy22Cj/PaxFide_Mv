/// Fechas cortas en español, como en el diseño: "1 oct 2026" y "3 oct 2026, 09:10" (hora del teléfono).
const _months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'];

/// "1 oct 2026". El texto original si no es una fecha.
String shortDate(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return iso.split('T').first;
  final d = iso.length <= 10 ? t : t.toLocal();
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// "3 oct 2026, 09:10" en la hora del teléfono. El texto original si no es una fecha.
String shortDateTime(String iso) {
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) return iso;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.day} ${_months[t.month - 1]} ${t.year}, ${two(t.hour)}:${two(t.minute)}';
}
