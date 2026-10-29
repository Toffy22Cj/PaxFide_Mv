/// Si el enlace de pago se puede abrir fuera de la app (auditoría 2026-10-29, S-02). Solo `https` y solo hacia los
/// hosts de PaxFide (la web pública o la API), que es donde está el checkout simulado. `http` solo hacia el mismo
/// origen configurado (la demo en la red local). Cualquier otro esquema (`intent:`, propios…) o host no se abre: se
/// muestra la dirección para copiarla, como decía DDM-31 (c).
bool isOpenablePaymentUrl(Uri url, {Uri? publicOrigin, Uri? apiBaseUrl}) {
  if (url.host.isEmpty) return false;
  final known = [publicOrigin, apiBaseUrl].whereType<Uri>();
  final sameHost = known.any((k) => k.host == url.host);
  if (url.scheme == 'https') return sameHost;
  if (url.scheme == 'http') return known.any((k) => k.scheme == 'http' && k.host == url.host);
  return false;
}
