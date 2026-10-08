/// Textos en español de los estados que devuelve el backend. Un valor
/// desconocido se muestra tal cual: nunca se traduce a otro.
String lifecycleLabel(String status) => switch (status) {
      'REGISTERED' => 'Registrado',
      'DISPATCHED' => 'En tránsito',
      'RECEIVED' => 'Recibido',
      'DELIVERED' => 'Entregado',
      'DEPLETED' => 'Agotado (dividido)',
      _ => status,
    };

String campaignStatusLabel(String status) => switch (status) {
      'OPEN' => 'Abierta',
      'CLOSED' => 'Cerrada',
      _ => status,
    };

String intentStatusLabel(String status) => switch (status) {
      'PENDING' => 'Pendiente de pago',
      'CONFIRMED' => 'Pago confirmado',
      'FAILED' => 'Pago fallido',
      'EXPIRED_UNKNOWN' => 'Caducada sin confirmar',
      'FUNDING_REJECTED' => 'Fondos rechazados',
      _ => status,
    };

String donationTypeLabel(String type) => switch (type) {
      'MONETARY' => 'Dinero',
      'IN_KIND' => 'En especie',
      _ => type,
    };

String unitLabel(String unit) => switch (unit) {
      'UNITS' => 'unidades',
      'KG' => 'kg',
      _ => unit,
    };

/// Fecha ISO-8601 → `AAAA-MM-DD` (sin inventar zona horaria).
String shortDate(String iso) => iso.length >= 10 ? iso.substring(0, 10) : iso;
