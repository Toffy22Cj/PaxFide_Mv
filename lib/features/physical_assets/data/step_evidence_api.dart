import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/credential_mode.dart';
import 'delivery_evidence_api.dart';

/// `POST /organizations/{organizationId}/asset-evidence` (ADR-051 Enmienda 2, Tarea 2; enmienda 7 de ADR-043): la foto
/// OPCIONAL de despachar o recibir. `multipart/form-data` con `file` (JPEG o PNG, como mucho 5 MB) y `step`
/// (`DISPATCHED` o `RECEIVED`, en mayúsculas), sin `Command-Id`. Devuelve el `evidenceRef` que el comando lleva. Los
/// mismos bytes del mismo paso dan el mismo `evidenceRef` (por eso un reintento por respuesta perdida es seguro).
/// Los fallos son los de la entrega (`EvidenceUploadException`: 413, 415, 410 y 503).
class StepEvidenceApi {
  const StepEvidenceApi(this._api);
  final ApiClient _api;

  static const dispatched = 'DISPATCHED';
  static const received = 'RECEIVED';

  static String uploadPath(String organizationId) =>
      '/organizations/${Uri.encodeComponent(organizationId)}/asset-evidence';

  static const _titled = {
    413: 'ImageTooLarge',
    415: 'UnsupportedImageFormat',
    410: 'EvidenceRemoved',
    503: 'MediaStorageUnavailable',
  };

  Future<String> upload({
    required String organizationId,
    required String step,
    required List<int> bytes,
    required String contentType,
    required String filename,
  }) async {
    assert(step == dispatched || step == received, 'solo DISPATCHED o RECEIVED');
    final r = await _api.postFile(
      uploadPath(organizationId),
      field: 'file',
      filename: filename,
      contentType: contentType,
      bytes: bytes,
      fields: {'step': step},
      credentialMode: CredentialMode.jwt,
    );
    if (_titled.containsKey(r.statusCode)) {
      final title = r.data?['title'];
      throw EvidenceUploadException(r.statusCode, title is String ? title : _titled[r.statusCode]!);
    }
    final ref = r.requireData()['evidenceRef'];
    if (ref is! String || !DeliveryEvidenceApi.evidenceRefPattern.hasMatch(ref)) throw const MalformedResponseException();
    return ref;
  }
}
