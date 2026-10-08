import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'app_services.dart';

/// Vista de cámara que entrega el texto del primer código leído.
typedef QrScannerBuilder = Widget Function(BuildContext context, ValueChanged<String> onCode);

/// `mobile_scanner` solo funciona en Android, iOS y macOS. En el resto (Linux, Windows) no hay cámara: se usa el
/// campo "pegar el enlace" de la hoja.
bool get cameraSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

Widget defaultQrScanner(BuildContext context, ValueChanged<String> onCode) => !cameraSupported
    ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('La cámara no está disponible en esta plataforma. Pega el enlace del QR abajo.'),
        ),
      )
    : MobileScanner(
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
  final _pasted = TextEditingController();

  @override
  void dispose() {
    _pasted.dispose();
    super.dispose();
  }

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
          // Alternativa sin cámara (escritorio, QR dañado): el texto pegado pasa por el mismo DeepLinkParser.
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              key: const Key('scanner.paste'),
              controller: _pasted,
              decoration: InputDecoration(
                labelText: 'O pega el enlace del QR',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  key: const Key('scanner.paste.open'),
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _pasted.text.trim().isEmpty ? null : _onCode(_pasted.text.trim()),
                ),
              ),
              onSubmitted: (v) => v.trim().isEmpty ? null : _onCode(v.trim()),
            ),
          ),
        ],
      ),
    );
  }
}
