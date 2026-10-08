/// Textos para el usuario de los estados que devuelve el backend. Un valor
/// desconocido se muestra tal cual: nunca se traduce a otro.
String lifecycleLabel(String status) => switch (status) {
      'REGISTERED' => 'En bodega',
      'DISPATCHED' => 'En camino',
      'RECEIVED' => 'Recibido',
      'DELIVERED' => 'Entregado',
      'DEPLETED' => 'Repartido en partes',
      _ => status,
    };

String campaignStatusLabel(String status) => switch (status) {
      'OPEN' => 'Abierta',
      'CLOSED' => 'Terminada',
      _ => status,
    };

String intentStatusLabel(String status) => switch (status) {
      'PENDING' => 'Esperando el pago',
      'CONFIRMED' => 'Pago recibido',
      'FAILED' => 'El pago no se completó',
      'EXPIRED_UNKNOWN' => 'El pago venció',
      'FUNDING_REJECTED' => 'No se pudo aplicar',
      _ => status,
    };

String donationTypeLabel(String type) => switch (type) {
      'MONETARY' => 'Dinero',
      'IN_KIND' => 'Productos',
      _ => type,
    };

String unitLabel(String unit) => switch (unit) {
      'UNITS' => 'unidades',
      'KG' => 'kg',
      _ => unit,
    };

const _months = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// `20 de noviembre` (y el año si no es el actual).
String longDate(DateTime d) {
  final local = d.toLocal();
  final year = local.year == DateTime.now().year ? '' : ' de ${local.year}';
  return '${local.day} de ${_months[local.month - 1]}$year';
}

/// Fecha ISO-8601 → `20 de noviembre`; si no se puede leer, el texto tal cual.
String shortDate(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : longDate(d);
}

/// Fecha y hora: `20 de noviembre, 14:05`.
String dateTime(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${longDate(d)}, ${two(d.hour)}:${two(d.minute)}';
}
