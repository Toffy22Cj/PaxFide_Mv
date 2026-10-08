import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/credential_mode.dart';

/// Cualquier fallo del código (inexistente, caducado, revocado): el backend da
/// el mismo 401 en todas las rutas de seguimiento (H-TR-1; antes se
/// documentaba 404, que también se trata igual). El cliente nunca distingue
/// la causa (§13) y nunca toca la sesión (T-1 no aplica a `tracking`).
class InvalidTrackingCodeException extends AppException {
  const InvalidTrackingCodeException() : super('Código no válido o expirado');
}

class FinancialSnapshot {
  const FinancialSnapshot({
    this.currency,
    required this.originalAmount,
    required this.clearedAmount,
    required this.pendingAllocationAmount,
    required this.confirmedAllocationAmount,
    required this.refundedAmount,
  });
  final String? currency;
  final int originalAmount;
  final int clearedAmount;
  final int pendingAllocationAmount;
  final int confirmedAllocationAmount;
  final int refundedAmount;
}

class LogisticsItem {
  const LogisticsItem({
    required this.assetRef,
    required this.lifecycleStatus,
    required this.assetType,
    required this.unitOfMeasure,
    required this.quantity,
    required this.locationZone,
    required this.custodianCategory,
  });
  final String assetRef;
  final String lifecycleStatus;
  final String assetType;
  final String unitOfMeasure;
  final String quantity;
  final String locationZone;
  final String custodianCategory;
}

/// `GET /donations/tracking` (EF3). Sin `donorRef` ni datos personales: no vienen. `campaignRef` no se expone.
class TrackingSummary {
  const TrackingSummary({required this.financial, required this.logistics, this.status});
  final FinancialSnapshot financial;
  final List<LogisticsItem> logistics;
  final String? status;
}

class TrackingNarrative {
  const TrackingNarrative({required this.status, this.content, this.source});
  final String status; // PENDING | AVAILABLE
  final String? content;
  final String? source; // LLM_GENERATED | FALLBACK_TEMPLATE
}

class HistoryEntry {
  const HistoryEntry({
    required this.eventType,
    required this.timestamp,
    required this.locationZone,
    required this.custodianCategory,
    required this.status,
  });
  final String eventType;
  final String timestamp;
  final String locationZone;
  final String custodianCategory;
  final String status;
}

/// Verificación de un lote de anclaje (`GET /donations/tracking/integrity`).
class IntegrityBatch {
  const IntegrityBatch({
    required this.anchorStatus,
    this.merkleRoot,
    this.transactionHash,
    this.network,
    this.anchoredAt,
    this.confirmedBlockNumber,
    required this.eventsOfThisDonation,
    required this.result,
    this.reason,
    this.reasonText,
  });
  final String anchorStatus;
  final String? merkleRoot;
  final String? transactionHash;
  final String? network;
  final String? anchoredAt;
  final String? confirmedBlockNumber;
  final int eventsOfThisDonation;

  /// `MATCH`, `MISMATCH` o `INCONCLUSIVE`.
  final String result;
  final String? reason;
  final String? reasonText;
}

class IntegrityReport {
  const IntegrityReport({required this.batches, required this.unanchoredEvents, required this.checkedAt});
  final List<IntegrityBatch> batches;
  final int unanchoredEvents;
  final String checkedAt;

  /// "Anclada y verificada" solo con todos los lotes en `MATCH` y ningún
  /// evento sin anclar (sugerencia de la API para los fronts).
  bool get fullyVerified => batches.isNotEmpty && unanchoredEvents == 0 && batches.every((b) => b.result == 'MATCH');

  bool get hasMismatch => batches.any((b) => b.result == 'MISMATCH');
}

/// Seguimiento del donante (referencia-api-v1 §8). El código viaja **solo** en la cabecera `Authorization`
/// (`CredentialMode.tracking`), nunca en la URL, en el estado de navegación ni en un log.
class TrackingApi {
  const TrackingApi(this._api);

  final ApiClient _api;

  Map<String, String> _auth(String code) => {'Authorization': 'Bearer $code'};

  Future<Map<String, dynamic>> _get(String path, String code) async {
    final ApiResponse r = await _api.get(path, headers: _auth(code), credentialMode: CredentialMode.tracking);
    if (r.statusCode == 404 || r.statusCode == 401) throw const InvalidTrackingCodeException();
    return r.requireData();
  }

  static int _int(Object? v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? (throw const MalformedResponseException());
    throw const MalformedResponseException();
  }

  static String _str(Map j, String k) => j[k] is String ? j[k] as String : (throw const MalformedResponseException());

  Future<TrackingSummary> summary(String code) async {
    final j = await _get('/donations/tracking', code);
    final f = j['financialSnapshot'];
    final logistics = j['logistics'];
    if (f is! Map || logistics is! List) throw const MalformedResponseException();
    return TrackingSummary(
      financial: FinancialSnapshot(
        currency: f['currency'] is String ? f['currency'] as String : null,
        originalAmount: _int(f['originalAmount']),
        clearedAmount: _int(f['clearedAmount']),
        pendingAllocationAmount: _int(f['pendingAllocationAmount']),
        confirmedAllocationAmount: _int(f['confirmedAllocationAmount']),
        refundedAmount: f.containsKey('refundedAmount') ? _int(f['refundedAmount']) : 0,
      ),
      logistics: [
        for (final l in logistics)
          if (l is Map)
            LogisticsItem(
              assetRef: _str(l, 'assetRef'),
              lifecycleStatus: _str(l, 'lifecycleStatus'),
              assetType: _str(l, 'assetType'),
              unitOfMeasure: _str(l, 'unitOfMeasure'),
              quantity: '${l['quantity']}',
              locationZone: l['locationZone'] is String ? l['locationZone'] as String : '',
              custodianCategory: l['custodianCategory'] is String ? l['custodianCategory'] as String : '',
            ),
      ],
      status: j['status'] is String ? j['status'] as String : null,
    );
  }

  Future<TrackingNarrative> narrative(String code) async {
    final j = await _get('/donations/tracking/narrative', code);
    return TrackingNarrative(
      status: _str(j, 'status'),
      content: j['content'] is String ? j['content'] as String : null,
      source: j['source'] is String ? j['source'] as String : null,
    );
  }

  Future<IntegrityReport> integrity(String code) async {
    final j = await _get('/donations/tracking/integrity', code);
    final batches = j['batches'];
    if (batches is! List) throw const MalformedResponseException();
    String? opt(Map m, String k) => m[k] == null ? null : '${m[k]}';
    return IntegrityReport(
      batches: [
        for (final b in batches)
          if (b is Map)
            IntegrityBatch(
              anchorStatus: '${b['anchorStatus'] ?? ''}',
              merkleRoot: opt(b, 'merkleRoot'),
              transactionHash: opt(b, 'transactionHash'),
              network: opt(b, 'network'),
              anchoredAt: opt(b, 'anchoredAt'),
              confirmedBlockNumber: opt(b, 'confirmedBlockNumber'),
              eventsOfThisDonation: b['eventsOfThisDonation'] is int ? b['eventsOfThisDonation'] as int : 0,
              result: b['verification'] is Map ? '${(b['verification'] as Map)['result'] ?? ''}' : '',
              reason: b['verification'] is Map ? opt(b['verification'] as Map, 'reason') : null,
              reasonText: b['verification'] is Map ? opt(b['verification'] as Map, 'reasonText') : null,
            ),
      ],
      unanchoredEvents: j['unanchoredEvents'] is int ? j['unanchoredEvents'] as int : 0,
      checkedAt: '${j['checkedAt'] ?? ''}',
    );
  }

  Future<List<HistoryEntry>> history(String code, String assetRef) async {
    final j = await _get('/donations/tracking/assets/${Uri.encodeComponent(assetRef)}/history', code);
    final h = j['history'];
    if (h is! List) throw const MalformedResponseException();
    return [
      for (final e in h)
        if (e is Map)
          HistoryEntry(
            eventType: '${e['eventType']}',
            timestamp: '${e['timestamp']}',
            locationZone: e['locationZone'] is String ? e['locationZone'] as String : '',
            custodianCategory: e['custodianCategory'] is String ? e['custodianCategory'] as String : '',
            status: '${e['status']}',
          ),
    ];
  }
}
