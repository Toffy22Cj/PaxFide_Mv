import '../data/delivery_evidence_api.dart';
import '../data/physical_asset_api.dart';
import 'asset_action.dart';

/// Campo de un formulario de comando (referencia-api-v1 §6): texto obligatorio de 1 a 256 caracteres.
class CommandField {
  const CommandField(this.key, this.label);
  final String key;
  final String label;
}

/// Comando de PhysicalAsset (`dispatch`/`receive`/`deliver`) listo para el Outbox: ruta y cuerpo exactos del
/// contrato. No incluye `organizationRef`, `donorRef` ni `deliveredAt` (los pone el servidor). Recibir y entregar
/// llevan además el `municipalityCode` elegido del catálogo DIVIPOLA.
///
/// Entregar lleva además el `evidenceRef` que devolvió la subida de la foto (ADR-051 F3): no se escribe a mano.
class AssetCommand {
  AssetCommand._(this.action, this.assetRef, this.values);

  static const int maxLength = 256;

  static const Map<AssetAction, List<CommandField>> fields = {
    AssetAction.dispatch: [CommandField('carrierRef', 'Transportista')],
    AssetAction.receive: [
      CommandField('facilityLocation', 'Lugar de recepción'),
      CommandField('receiverRef', 'Quién recibe'),
    ],
    AssetAction.deliver: [
      CommandField('finalCustodianRef', 'Custodio final'),
      CommandField('beneficiaryRef', 'Beneficiario (referencia)'),
      CommandField('locationRef', 'Lugar de entrega'),
    ],
  };

  /// Recibir y entregar llevan el municipio DIVIPOLA de 5 dígitos (enmienda 2 de ADR-029; el backend da 400 sin él).
  /// Despachar no: el backend sella la zona del paso anterior.
  static bool needsMunicipality(AssetAction action) => action == AssetAction.receive || action == AssetAction.deliver;

  static final _municipalityCode = RegExp(r'^[0-9]{5}$');

  /// Valida y construye. Devuelve los nombres de los campos inválidos en [errors] (vacío si es válido). Para entregar
  /// hace falta [evidenceRef] con la forma `sha256:<64 hex>`; si no, el error es `evidenceRef`. Para recibir y
  /// entregar, [municipalityCode]; si no, el error es `municipalityCode`.
  static AssetCommand? build(
    AssetAction action,
    String assetRef,
    Map<String, String> input, {
    String? evidenceRef,
    String? municipalityCode,
    List<String>? errors,
  }) {
    final spec = fields[action];
    if (spec == null) return null; // readOnly no tiene comando
    final values = <String, String>{};
    for (final f in spec) {
      final v = (input[f.key] ?? '').trim();
      if (v.isEmpty || v.length > maxLength) {
        errors?.add(f.key);
      } else {
        values[f.key] = v;
      }
    }
    var valid = values.length == spec.length;
    if (action == AssetAction.deliver) {
      if (evidenceRef == null || !DeliveryEvidenceApi.evidenceRefPattern.hasMatch(evidenceRef)) {
        errors?.add('evidenceRef');
        valid = false;
      } else {
        values['evidenceRef'] = evidenceRef;
      }
    }
    if (needsMunicipality(action)) {
      if (municipalityCode == null || !_municipalityCode.hasMatch(municipalityCode)) {
        errors?.add('municipalityCode');
        valid = false;
      } else {
        values['municipalityCode'] = municipalityCode;
      }
    }
    if (!valid) return null;
    return AssetCommand._(action, assetRef, values);
  }

  final AssetAction action;
  final String assetRef;
  final Map<String, String> values;

  String get path => '${PhysicalAssetApi.assetPath(assetRef)}/${action.name}';
  Map<String, dynamic> get body => Map.unmodifiable(values);
}
