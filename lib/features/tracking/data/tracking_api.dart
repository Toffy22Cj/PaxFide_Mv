import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/credential_mode.dart';

/// Cualquier fallo del código (inexistente, caducado, revocado): el backend da el mismo 404 (TR-D1); 401 también se
/// trata igual. El cliente nunca distingue la causa (§13).
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
    this.firstClearedAt,
    this.lastClearedAt,
  });
  final String? currency;
  final int originalAmount;
  final int clearedAmount;
  final int pendingAllocationAmount;
  final int confirmedAllocationAmount;
  final int refundedAmount;

  /// Primer y último `FUNDS_CLEARED` (G-2); faltan sin liquidaciones.
  final String? firstClearedAt;
  final String? lastClearedAt;
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
    this.parentAssetRef,
  });
  final String assetRef;
  final String lifecycleStatus;
  final String assetType;
  final String unitOfMeasure;
  final String quantity;
  final String locationZone;
  final String custodianCategory;

  /// Lote del que salió este sublote (G-4): siempre otro ítem de la misma lista; si no, falta.
  final String? parentAssetRef;
}

/// `GET /donations/tracking` (EF3). Sin `donorRef` ni datos personales: no vienen. `campaignRef` no se expone.
class TrackingSummary {
  const TrackingSummary({
    required this.financial,
    required this.logistics,
    this.status,
    this.campaignTitle,
    this.organizationName,
  });
  final FinancialSnapshot financial;
  final List<LogisticsItem> logistics;
  final String? status;

  /// G-1: faltan si la donación no tiene convocatoria o no se encuentra. Nunca ciudad ni destinatario.
  final String? campaignTitle;
  final String? organizationName;
}

class TrackingNarrative {
  const TrackingNarrative({required this.status, this.content, this.source});
  final String status; // PENDING | AVAILABLE
  final String? content;
  final String? source; // LLM_GENERATED | FALLBACK_TEMPLATE
}

/// Prueba de que la huella de un paso está en la raíz anclada (ADR-039 Enmienda 1, E1). La app la muestra; no la
/// recalcula (decisión del 2026-10-28: el estado y las huellas, sin verificación en el teléfono).
class AnchorProof {
  const AnchorProof({required this.merkleRoot, required this.transactionHash, required this.network, this.anchoredAt});
  final String merkleRoot;
  final String transactionHash;
  final String network;
  final String? anchoredAt;
}

class HistoryEntry {
  const HistoryEntry({
    required this.eventType,
    required this.timestamp,
    required this.locationZone,
    required this.custodianCategory,
    required this.status,
    this.anchorStatus = 'PENDING',
    this.eventHash,
    this.anchorProof,
    this.evidenceRegistered,
    this.evidenceRef,
  });
  final String eventType;
  final String timestamp;
  final String locationZone;
  final String custodianCategory;
  final String status;

  /// `ANCHORED`, `IN_BATCH`, `PENDING` o `UNDER_REVIEW` (G-3).
  final String anchorStatus;

  /// Huella del evento: 64 hexadecimales en minúscula. Falta en proyecciones antiguas.
  final String? eventHash;
  final AnchorProof? anchorProof;

  /// Solo en la entrega: si el evento lleva una evidencia (ADR-051 F6). La foto nunca sale.
  final bool? evidenceRegistered;

  /// Solo en la entrega y solo con la forma `sha256:<64 hex>`.
  final String? evidenceRef;
}

/// Un lote de anclaje con eventos de esta donación (`GET /donations/tracking/integrity`, P4).
class IntegrityBatch {
  const IntegrityBatch({
    required this.anchorStatus,
    required this.eventsOfThisDonation,
    required this.result,
    this.merkleRoot,
    this.transactionHash,
    this.network,
    this.anchoredAt,
    this.reason,
    this.reasonText,
    this.affectsThisDonation,
  });
  final String anchorStatus;
  final int eventsOfThisDonation;

  /// `MATCH`, `MISMATCH` o `INCONCLUSIVE`, calculado por el servidor.
  final String result;
  final String? merkleRoot;
  final String? transactionHash;
  final String? network;
  final String? anchoredAt;
  final String? reason;
  final String? reasonText;
  final bool? affectsThisDonation;
}

/// Resultado global para la pantalla, a partir de los lotes.
enum IntegrityVerdict { verified, partial, pending, inconclusive, mismatch }

class TrackingIntegrity {
  const TrackingIntegrity({required this.batches, required this.unanchoredEvents, required this.checkedAt});
  final List<IntegrityBatch> batches;
  final int unanchoredEvents;
  final String checkedAt;

  /// Una diferencia que afecta (o puede afectar) a esta donación manda sobre todo lo demás; después, lo no
  /// comprobable; después, lo que falta por sellar.
  IntegrityVerdict get verdict {
    if (batches.any((b) => b.result == 'MISMATCH' && b.affectsThisDonation != false)) return IntegrityVerdict.mismatch;
    if (batches.any((b) => b.result == 'INCONCLUSIVE' && b.reason != 'NOT_ANCHORED')) {
      return IntegrityVerdict.inconclusive;
    }
    final verified = batches.where((b) => b.result == 'MATCH');
    if (verified.isEmpty) return IntegrityVerdict.pending;
    final open = unanchoredEvents > 0 || batches.any((b) => b.result != 'MATCH');
    return open ? IntegrityVerdict.partial : IntegrityVerdict.verified;
  }
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
        firstClearedAt: _opt(f, 'firstClearedAt'),
        lastClearedAt: _opt(f, 'lastClearedAt'),
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
              parentAssetRef: _opt(l, 'parentAssetRef'),
            ),
      ],
      status: j['status'] is String ? j['status'] as String : null,
      campaignTitle: _opt(j, 'campaignTitle'),
      organizationName: _opt(j, 'organizationName'),
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
            anchorStatus: e['anchorStatus'] is String ? e['anchorStatus'] as String : 'PENDING',
            eventHash: _hash(e['eventHash']),
            anchorProof: _proof(e['anchorProof']),
            evidenceRegistered: e['evidenceRegistered'] is bool ? e['evidenceRegistered'] as bool : null,
            evidenceRef: e['evidenceRef'] is String && _evidence.hasMatch(e['evidenceRef'] as String)
                ? e['evidenceRef'] as String
                : null,
          ),
    ];
  }

  static final _hex64 = RegExp(r'^[0-9a-f]{64}$');
  static final _evidence = RegExp(r'^sha256:[0-9a-f]{64}$');

  static String? _hash(Object? v) => v is String && _hex64.hasMatch(v) ? v : null;

  static String? _opt(Map j, String k) => j[k] is String && (j[k] as String).isNotEmpty ? j[k] as String : null;

  static AnchorProof? _proof(Object? p) {
    if (p is! Map) return null;
    final root = _hash(p['merkleRoot']);
    final tx = _opt(p, 'transactionHash');
    final network = _opt(p, 'network');
    if (root == null || tx == null || network == null) return null;
    return AnchorProof(merkleRoot: root, transactionHash: tx, network: network, anchoredAt: _opt(p, 'anchoredAt'));
  }

  /// `GET /donations/tracking/integrity`: lo comprueba el servidor (no-store, caché de 5 min por lote).
  Future<TrackingIntegrity> integrity(String code) async {
    final j = await _get('/donations/tracking/integrity', code);
    final batches = j['batches'];
    if (batches is! List) throw const MalformedResponseException();
    return TrackingIntegrity(
      unanchoredEvents: j['unanchoredEvents'] is int ? j['unanchoredEvents'] as int : 0,
      checkedAt: '${j['checkedAt'] ?? ''}',
      batches: [
        for (final b in batches)
          if (b is Map && b['verification'] is Map)
            IntegrityBatch(
              anchorStatus: '${b['anchorStatus']}',
              eventsOfThisDonation: b['eventsOfThisDonation'] is int ? b['eventsOfThisDonation'] as int : 0,
              result: '${(b['verification'] as Map)['result']}',
              reason: _opt(b['verification'] as Map, 'reason'),
              reasonText: _opt(b['verification'] as Map, 'reasonText'),
              affectsThisDonation: (b['verification'] as Map)['affectsThisDonation'] is bool
                  ? (b['verification'] as Map)['affectsThisDonation'] as bool
                  : null,
              merkleRoot: _opt(b, 'merkleRoot'),
              transactionHash: _opt(b, 'transactionHash'),
              network: _opt(b, 'network'),
              anchoredAt: _opt(b, 'anchoredAt'),
            ),
      ],
    );
  }
}
