import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'app_services.dart';

/// Vista de cámara que entrega el texto del primer código leído.
typedef QrScannerBuilder = Widget Function(BuildContext context, ValueChanged<String> onCode);

Widget defaultQrScanner(BuildContext context, ValueChanged<String> onCode) => MobileScanner(
  onDetect: (capture) {
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw != null && raw.isNotEmpty) {
        onCode(raw);
        return;
      }
    }
  },
);

/// Escáner interno: superficie transitoria (no es una ruta, §9). Todo lo leído pasa por el único
/// `DeepLinkParser` y entra por `openDeepLink` (D9 R1). Nunca ejecuta comandos ni toca el Outbox (R3).
Future<void> scanQr(BuildContext context) async {
  final services = AppScope.of(context);
  final raw = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _ScannerSheet(builder: services.qrScannerBuilder),
  );
  if (raw == null || !context.mounted) return;
  final link = services.deepLinkParser.parseText(raw);
  final opened = link.isApproved && await services.router.openDeepLink(link);
  if (!opened && context.mounted) {
    final reason = services.config.publicOrigin == null
        ? 'La app no tiene configurado el origen de los enlaces de PaxFide.'
        : 'Este código QR no es un enlace de PaxFide reconocido.';
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(reason)));
  }
}

class _ScannerSheet extends StatefulWidget {
  const _ScannerSheet({required this.builder});
  final QrScannerBuilder builder;

  @override
  State<_ScannerSheet> createState() => _ScannerSheetState();
}

class _ScannerSheetState extends State<_ScannerSheet> {
  bool _done = false;

  void _onCode(String raw) {
    if (_done) return; // solo el primer código
    _done = true;
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        children: [
          ListTile(
            title: const Text('Escanear un código QR'),
            subtitle: const Text('Activo, convocatoria o seguimiento'),
            trailing: IconButton(
              tooltip: 'Cerrar',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(child: ClipRect(child: widget.builder(context, _onCode))),
        ],
      ),
    );
  }
}
