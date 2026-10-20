import '../data/campaign_api.dart';

/// M-07: ¿la organización de una convocatoria está verificada? Interfaz para que la pantalla no dependa de dónde sale
/// el dato. Solo se pinta la insignia ante un "sí" explícito: sin dato, no se afirma nada.
abstract interface class OrganizationVerification {
  bool isVerified(PublicCampaign campaign);
}

/// Lee `verificationStatus` de la respuesta pública de la convocatoria (`VERIFIED`, ADR-038). Mientras el backend no
/// lo exponga, nunca devuelve verdadero (ver PENDIENTES_ADONIS.md).
class PublicFieldVerification implements OrganizationVerification {
  const PublicFieldVerification();

  @override
  bool isVerified(PublicCampaign campaign) => campaign.verificationStatus == 'VERIFIED';
}
