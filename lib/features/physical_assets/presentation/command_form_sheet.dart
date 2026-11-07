import '../domain/asset_action.dart';

/// Nombre de cada acción de campo, para botones y títulos.
String actionLabel(AssetAction a) => switch (a) {
  AssetAction.dispatch => 'Despachar',
  AssetAction.receive => 'Recibir',
  AssetAction.deliver => 'Entregar',
  AssetAction.readOnly => 'Solo lectura',
};
