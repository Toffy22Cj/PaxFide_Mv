/// Estado de una convocatoria **para mostrar**: el backend la deja `OPEN` hasta que alguien la cierra, aunque ya
/// haya pasado su fecha de cierre. La app la trata como terminada en cuanto pasa `endDate`: no sale entre las
/// abiertas, no ofrece donar y dice «Terminada» y «Cerró el …» (el backend sigue siendo quien acepta o rechaza).
library;

/// Ya pasó su fecha de cierre (o no se puede leer: entonces no se da por terminada).
bool campaignEnded(String endDate, {DateTime? now}) {
  final end = DateTime.tryParse(endDate);
  if (end == null) return false;
  return !end.isAfter(now ?? DateTime.now());
}

/// Abierta de verdad: `OPEN` y sin pasar la fecha de cierre.
bool campaignOpen(String status, String endDate, {DateTime? now}) =>
    status == 'OPEN' && !campaignEnded(endDate, now: now);

/// `OPEN`, `CLOSED` o `ENDED` (abierta en el backend pero con la fecha de cierre ya pasada).
String effectiveCampaignStatus(String status, String endDate, {DateTime? now}) =>
    status == 'OPEN' && campaignEnded(endDate, now: now) ? 'ENDED' : status;
