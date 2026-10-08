/// Cantidades del contrato: texto decimal (escala 4 en el dominio, p. ej. `"10.0000"`). Se muestran sin ceros
/// sobrantes y **sin redondear**: es una operación de texto, nunca de coma flotante.
String formatQuantity(String raw) {
  final m = RegExp(r'^(-?[0-9]+)(?:\.([0-9]*))?$').firstMatch(raw.trim());
  if (m == null) return raw;
  final fraction = (m.group(2) ?? '').replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? m.group(1)! : '${m.group(1)},$fraction';
}

String formatQuantityWithUnit(String? quantity, String? unit) {
  final parts = [if (quantity != null) formatQuantity(quantity), ?unit];
  return parts.isEmpty ? '—' : parts.join(' ');
}
