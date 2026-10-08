import '../data/physical_asset_api.dart';
import 'asset_action.dart';

/// Campo de un formulario de comando (referencia-api-v1 §6): texto obligatorio de 1 a 256 caracteres.
class CommandField {
  const CommandField(this.key, this.label);
  final String key;
  final String label;
}

/// Comando de PhysicalAsset (`dispatch`/`receive`/`deliver`) listo para el Outbox: ruta y cuerpo exactos del
/// contrato. No incluye `organizationRef`, `donorRef` ni `deliveredAt` (los pone el servidor).
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
      CommandField('evidenceRef', 'Referencia de la evidencia'),
    ],
  };

  /// Valida y construye. Devuelve los nombres de los campos inválidos en [errors] (vacío si es válido).
  static AssetCommand? build(AssetAction action, String assetRef, Map<String, String> input, {List<String>? errors}) {
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
    if (values.length != spec.length) return null;
    return AssetCommand._(action, assetRef, values);
  }

  final AssetAction action;
  final String assetRef;
  final Map<String, String> values;

  String get path => '${PhysicalAssetApi.assetPath(assetRef)}/${action.name}';
  Map<String, dynamic> get body => Map.unmodifiable(values);
}
