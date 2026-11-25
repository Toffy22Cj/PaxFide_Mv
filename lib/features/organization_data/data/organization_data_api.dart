import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/credential_mode.dart';

/// Una lectura con la marca de si salió de lo guardado sin conexión (Enmienda 4 de ADR-043, S2) y de cuándo se guardó
/// (Enmienda 6, E6-6: «el gráfico dice la fecha de esa respuesta»).
class Loaded<T> {
  const Loaded(this.value, {this.fromCache = false, this.cachedAt});
  final T value;
  final bool fromCache;

  /// Cuándo se guardó la respuesta que se muestra; `null` si venía de la red o si no se sabe.
  final DateTime? cachedAt;
}

/// Una fila de `GET /organizations/{id}/funds/monthly`: un mes y una moneda. El importe es texto de dígitos en unidades
/// mínimas (referencia-api-v1 §0); los meses vacíos llegan en `"0"` y se dibujan en cero.
class MonthlyFundsRow {
  const MonthlyFundsRow({required this.month, required this.currency, required this.clearedAmount});
  final String month;
  final String currency;
  final String clearedAmount;
}

class MonthlyFunds {
  const MonthlyFunds({required this.items, this.truncated = false});
  final List<MonthlyFundsRow> items;
  final bool truncated;

  static MonthlyFunds fromJson(Map<String, dynamic> j) {
    final items = j['items'];
    if (items is! List) throw const MalformedResponseException();
    final rows = <MonthlyFundsRow>[];
    for (final i in items) {
      if (i is! Map || i['month'] is! String || i['currency'] is! String) throw const MalformedResponseException();
      final amount = i['clearedAmount'];
      if (amount is! String && amount is! num) throw const MalformedResponseException();
      rows.add(MonthlyFundsRow(month: i['month'] as String, currency: i['currency'] as String, clearedAmount: '$amount'));
    }
    return MonthlyFunds(items: rows, truncated: j['truncated'] == true);
  }
}

/// Un evento de `GET /organizations/{id}/activity`. Solo lo que el backend da: nunca el actor, el donante ni importes.
class ActivityEvent {
  const ActivityEvent({required this.type, required this.occurredAt, this.subjectKind, this.eventCount, this.locationZone});
  final String type;
  final DateTime occurredAt;
  final String? subjectKind;
  final int? eventCount;
  final String? locationZone;
}

class OrganizationActivity {
  const OrganizationActivity({required this.events, required this.more});

  /// De lo más reciente a lo más antiguo, como mucho [OrganizationDataApi.activityLimit].
  final List<ActivityEvent> events;

  /// Hay más eventos de los que se cargaron: el gráfico lo dice.
  final bool more;
}

/// Las dos lecturas de la Enmienda 6 de ADR-043. Solo lectura; el backend autoriza cada una (DD-31, D-R6-8) y un 403 llega
/// como [ForbiddenException].
class OrganizationDataApi {
  const OrganizationDataApi(this._api);
  final ApiClient _api;

  /// Como mucho 100 eventos (5 páginas de 20), como la web.
  static const activityLimit = 100;
  static const _cachedHeader = 'x-paxfide-cached';
  static const _cachedAtHeader = 'x-paxfide-cached-at';

  static DateTime? _cachedAt(Map<String, String> headers) {
    final raw = headers[_cachedAtHeader];
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// `months`: de 1 a 12 (el backend da 400 fuera de ese rango).
  Future<Loaded<MonthlyFunds>> fundsMonthly(String organizationId, {int months = 12}) async {
    final r = await _api.get(
      '/organizations/${Uri.encodeComponent(organizationId)}/funds/monthly',
      queryParams: {'months': '$months'},
      credentialMode: CredentialMode.jwt,
    );
    final value = MonthlyFunds.fromJson(r.requireData());
    return Loaded(value, fromCache: r.headers[_cachedHeader] == 'true', cachedAt: _cachedAt(r.headers));
  }

  Future<Loaded<OrganizationActivity>> activity(String organizationId) async {
    final events = <ActivityEvent>[];
    String? cursor;
    var more = false;
    var fromCache = false;
    DateTime? oldest;
    do {
      final r = await _api.get(
        '/organizations/${Uri.encodeComponent(organizationId)}/activity',
        queryParams: cursor == null ? null : {'cursor': cursor},
        credentialMode: CredentialMode.jwt,
      );
      final j = r.requireData();
      final items = j['items'];
      if (items is! List) throw const MalformedResponseException();
      for (final i in items) {
        if (i is! Map || i['type'] is! String || i['occurredAt'] is! String) throw const MalformedResponseException();
        final at = DateTime.tryParse(i['occurredAt'] as String);
        if (at == null) throw const MalformedResponseException();
        final subject = i['subject'];
        events.add(
          ActivityEvent(
            type: i['type'] as String,
            occurredAt: at,
            subjectKind: subject is Map && subject['kind'] is String ? subject['kind'] as String : null,
            eventCount: i['eventCount'] is int ? i['eventCount'] as int : null,
            locationZone: i['locationZone'] is String ? i['locationZone'] as String : null,
          ),
        );
      }
      if (r.headers[_cachedHeader] == 'true') {
        fromCache = true;
        final at = _cachedAt(r.headers);
        if (at != null && (oldest == null || at.isBefore(oldest))) oldest = at;
      }
      final next = j['nextCursor'];
      cursor = next is String && next.isNotEmpty ? next : null;
      if (events.length >= activityLimit) {
        more = cursor != null || events.length > activityLimit;
        cursor = null;
      }
    } while (cursor != null);
    final shown = events.length > activityLimit ? events.sublist(0, activityLimit) : events;
    return Loaded(OrganizationActivity(events: shown, more: more), fromCache: fromCache, cachedAt: oldest);
  }
}
