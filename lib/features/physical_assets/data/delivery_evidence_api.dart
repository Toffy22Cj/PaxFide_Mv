import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/credential_mode.dart';

/// Fallos con nombre de la subida de la foto de entrega (ADR-051). [code] es el `title` del backend o el estado.
class EvidenceUploadException extends ApiHttpException {
  const EvidenceUploadException(int statusCode, this.code)
    : super(statusCode, 'No se pudo subir la foto de la entrega');

  /// `ImageTooLarge` (413), `UnsupportedImageFormat` (415), `EvidenceRemoved` (410) o `MediaStorageUnavailable` (503).
  final String code;
}

/// `POST /organizations/{organizationId}/delivery-evidence` (ADR-051 F2–F5): `multipart/form-data` con el campo
/// `file` (JPEG o PNG, como mucho 5 MB), sin `Command-Id`. Devuelve el `evidenceRef` (`sha256:<64 hex>`) que la
/// entrega tiene que llevar. Los mismos bytes devuelven el mismo `evidenceRef` sin duplicar (F9).
class DeliveryEvidenceApi {
  const DeliveryEvidenceApi(this._api);
  final ApiClient _api;

  static final evidenceRefPattern = RegExp(r'^sha256:[0-9a-f]{64}$');

  static const _titled = {
    413: 'ImageTooLarge',
    415: 'UnsupportedImageFormat',
    410: 'EvidenceRemoved',
    503: 'MediaStorageUnavailable',
  };

  Future<String> upload({
    required String organizationId,
    required List<int> bytes,
    required String contentType,
    required String filename,
  }) async {
    final r = await _api.postFile(
      '/organizations/${Uri.encodeComponent(organizationId)}/delivery-evidence',
      field: 'file',
      filename: filename,
      contentType: contentType,
      bytes: bytes,
      credentialMode: CredentialMode.jwt,
    );
    if (_titled.containsKey(r.statusCode)) {
      final title = r.data?['title'];
      throw EvidenceUploadException(r.statusCode, title is String ? title : _titled[r.statusCode]!);
    }
    final ref = r.requireData()['evidenceRef'];
    if (ref is! String || !evidenceRefPattern.hasMatch(ref)) throw const MalformedResponseException();
    return ref;
  }
}
