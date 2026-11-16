import 'dart:convert';

import '../../core/storage/secure_key_value_store.dart';

/// Los paneles con gráficos (plan del paso 3). En el móvil, por ahora, predicción y lotes; fondos y actividad
/// esperan a la Enmienda 6 de ADR-043.
enum ChartPanelId { prediction, assets }

class ChartChoice {
  const ChartChoice({this.simple, this.advanced});
  final String? simple;
  final String? advanced;

  ChartChoice copyWith({String? simple, String? advanced}) =>
      ChartChoice(simple: simple ?? this.simple, advanced: advanced ?? this.advanced);
}

/// Dónde se guarda qué tipo de gráfico eligió cada cuenta (decisión de Manuel del 2026-11-15 y condición del
/// 2026-11-16): en el teléfono, cifrado (`flutter_secure_storage`, ya aprobado, A2/D12), por **cuenta** (`accountId`
/// de `/me`, nunca el correo) y panel. No es una autorización: solo qué tipo se dibuja. Si falla, valen los
/// predeterminados.
class ChartPreferenceStore {
  const ChartPreferenceStore([this._store]);

  final SecureKeyValueStore? _store;

  static String keyFor(String accountId, ChartPanelId panel) => 'paxfide.charts.v1.$accountId.${panel.name}';

  /// Un tipo que ya no está entre los permitidos se ignora (vuelve el predeterminado).
  Future<ChartChoice> read(
    String accountId,
    ChartPanelId panel, {
    required List<String> simple,
    required List<String> advanced,
  }) async {
    try {
      final raw = await _store?.read(keyFor(accountId, panel));
      if (raw == null) return const ChartChoice();
      final j = jsonDecode(raw);
      if (j is! Map) return const ChartChoice();
      final s = j['simple'], a = j['advanced'];
      return ChartChoice(
        simple: s is String && simple.contains(s) ? s : null,
        advanced: a is String && advanced.contains(a) ? a : null,
      );
    } catch (_) {
      return const ChartChoice();
    }
  }

  /// Devuelve si se guardó; si no, la elección vale para esta sesión.
  Future<bool> write(String accountId, ChartPanelId panel, ChartChoice choice) async {
    final store = _store;
    if (store == null) return false;
    try {
      await store.write(keyFor(accountId, panel), jsonEncode({'simple': ?choice.simple, 'advanced': ?choice.advanced}));
      return true;
    } catch (_) {
      return false;
    }
  }
}
