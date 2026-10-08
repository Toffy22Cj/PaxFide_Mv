import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'app_routes.dart';
import 'app_services.dart';
import 'deep_link_parser.dart';
import 'pending_intent.dart';

/// Vista de cámara que entrega el texto del primer código leído.
typedef QrScannerBuilder = Widget Function(BuildContext context, ValueChanged<String> onCode);

/// `mobile_scanner` solo funciona en Android, iOS y macOS. En el resto no hay
/// cámara: se usa el campo "pegar el enlace" de la hoja (DDM-42).
bool get cameraSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

Widget defaultQrScanner(BuildContext context, ValueChanged<String> onCode) => !cameraSupported
    ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No hay cámara disponible. Pega el enlace del código abajo.',
            textAlign: TextAlign.center,
          ),
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

/// Abre un enlace ya aprobado por el [DeepLinkParser].
///
/// Un destino autenticado sin sesión deja un [PendingIntent] en memoria; el
/// guard manda a `/login` y, tras entrar, se consume una vez (D9 R2). Nunca
/// ejecuta comandos ni toca el Outbox (R3).
void openParsedLink(BuildContext context, ParsedDeepLink link) {
  final services = AppScope.of(context);
  if (link.category == RouteCategory.authenticated && !services.session.value.isAuthenticated) {
    services.pendingIntents.set(PendingIntent(route: link.route, params: link.parameters));
  }
  Navigator.of(context).pushNamed(link.route);
}

/// Escáner interno: superficie transitoria (no es una ruta). Todo lo leído
/// pasa por el único `DeepLinkParser` (D9 R1).
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
  if (link.isApproved) {
    openParsedLink(context, link);
    return;
  }
  final reason = services.config.publicOrigin == null
      ? 'La app no puede leer códigos QR en esta instalación.'
      : 'Este código QR no es de PaxFide.';
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(reason)));
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
            subtitle: const Text('De un envío o de una causa'),
            trailing: IconButton(
              tooltip: 'Cerrar',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(child: ClipRect(child: widget.builder(context, _onCode))),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              key: const Key('scanner-paste'),
              controller: _pasted,
              decoration: InputDecoration(
                labelText: 'O pega aquí el enlace del código',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  key: const Key('scanner-paste-open'),
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
