import '../../../core/network/api_client.dart';
import '../../../core/network/credential_mode.dart';
import '../../campaigns/data/campaign_api.dart';
import '../../prediction/data/prediction_api.dart';

/// El nombre de la organización de la cuenta, con lo que el backend le deja leer a cada rol (C4b):
/// - `ADMINISTRATOR` o `REPRESENTATIVE`: `GET /organizations/{id}` (ficha S-18), que trae `name`.
/// - `EMPLOYEE`: esa ruta le responde 403, así que se toma de la ficha pública de una de sus convocatorias
///   (`GET /me/campaigns` → `GET /public/campaigns/{publicCode}`, que lleva `organizationName`).
/// `null` si no se puede saber (por ejemplo, un empleado sin convocatorias asignadas).
Future<String?> loadOrganizationName(
  ApiClient api, {
  required String? organizationId,
  required Set<String> roles,
}) async {
  final org = organizationId;
  if (org == null) return null;
  if (roles.contains('ADMINISTRATOR') || roles.contains('REPRESENTATIVE')) {
    try {
      final r = await api.get('/organizations/${Uri.encodeComponent(org)}', credentialMode: CredentialMode.jwt);
      final name = r.data?['name'];
      if (r.isSuccess && name is String && name.trim().isNotEmpty) return name.trim();
    } on Object {
      // sigue con las convocatorias
    }
  }
  try {
    final campaigns = await PredictionApi(api).myCampaigns();
    for (final c in campaigns) {
      final code = c.publicCode;
      if (code == null || code.isEmpty) continue;
      try {
        final name = (await CampaignApi(api).get(code)).organizationName.trim();
        if (name.isNotEmpty) return name;
      } on Object {
        continue;
      }
    }
  } on Object {
    return null;
  }
  return null;
}
