import 'package:flutter/material.dart';

import '../core/offline/outbox_status.dart';
import 'app_services.dart';

/// Cuántas operaciones de la cuenta hay guardadas en el teléfono sin confirmar.
///
/// Rendimiento: lee el almacén (cifrado) solo al montarse y cuando el `SyncEngine` avisa de un cambio, nunca en cada
/// reconstrucción; y mientras lee muestra el último número, así el contador no parpadea a 0.
class PendingCountBuilder extends StatefulWidget {
  const PendingCountBuilder({super.key, required this.builder});
  final Widget Function(BuildContext context, int count) builder;

  @override
  State<PendingCountBuilder> createState() => _PendingCountBuilderState();
}

class _PendingCountBuilderState extends State<PendingCountBuilder> {
  late final AppServices _services = AppScope.of(context);
  int _count = 0;
  int _reads = 0;
  bool _listening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_listening) return;
    _listening = true;
    _services.syncEngine.addListener(_load);
    _services.session.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _services.syncEngine.removeListener(_load);
    _services.session.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final read = ++_reads;
    final account = _services.session.principal?.accountId;
    var n = 0;
    if (account != null) {
      try {
        n = (await _services.syncEngine.entriesFor(account)).where((i) => i.status != OutboxStatus.acknowledged).length;
      } on Object {
        n = 0;
      }
    }
    // Solo cuenta la lectura más reciente.
    if (mounted && read == _reads && n != _count) setState(() => _count = n);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _count);
}
