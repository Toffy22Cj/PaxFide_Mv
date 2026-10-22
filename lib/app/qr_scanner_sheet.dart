import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../shared/widgets/pax_ui.dart';
import 'app_routes.dart';
import 'app_services.dart';
import '../shared/widgets/pax_app_bar.dart';

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
          child: Text('La cámara no está disponible en este equipo. Pega o escribe la referencia abajo.'),
        ),
      )
    : _CameraScanner(onCode: onCode);

/// Cámara con linterna (alternar). El marco de encuadre lo pone la hoja, encima de cualquier escáner.
class _CameraScanner extends StatefulWidget {
  const _CameraScanner({required this.onCode});
  final ValueChanged<String> onCode;

  @override
  State<_CameraScanner> createState() => _CameraScannerState();
}

class _CameraScannerState extends State<_CameraScanner> {
  final _controller = MobileScannerController();
  bool _torch = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          for (final b in capture.barcodes) {
            final raw = b.rawValue;
            if (raw != null && raw.isNotEmpty) {
              widget.onCode(raw);
              return;
            }
          }
        },
      ),
      Positioned(
        left: 12,
        right: 12,
        bottom: 12,
        child: FilledButton.tonalIcon(
          key: const Key('scanner.torch'),
          icon: Icon(_torch ? Icons.flashlight_off : Icons.flashlight_on),
          label: Text(_torch ? 'Apagar linterna' : 'Linterna'),
          onPressed: () async {
            await _controller.toggleTorch();
            if (mounted) setState(() => _torch = !_torch);
          },
        ),
      ),
    ],
  );
}

/// Escáner interno: superficie transitoria (no es una ruta, §9). Todo lo leído pasa por el único
/// `DeepLinkParser` y entra por `openDeepLink` (D9 R1). Nunca ejecuta comandos ni toca el Outbox (R3).
Future<void> scanQr(BuildContext context) async {
  final services = AppScope.of(context);
  final raw = await Navigator.of(context).push<String>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => _ScannerSheet(builder: services.qrScannerBuilder)),
  );
  if (raw == null || !context.mounted) return;
  // Una referencia escrita a mano (sin enlace) abre directamente la ficha del activo.
  if (AppRoutes.isValidParam(raw) && !raw.contains(':')) {
    services.router.push(AppRoutes.assetPath(raw));
    return;
  }
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

  /// Botón "Pegar" (M-19): trae el texto del portapapeles al campo.
  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty && mounted) setState(() => _pasted.text = text);
  }

  void _onCode(String raw) {
    if (_done) return; // solo el primer código
    _done = true;
    HapticFeedback.mediumImpact(); // vibración al leer
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: PaxAppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Escanear un código QR'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Activo o convocatoria', style: theme.textTheme.labelMedium?.copyWith(color: muted)),
            const SizedBox(height: 10),
            SizedBox(
              height: (MediaQuery.sizeOf(context).width - 32).clamp(160.0, 320.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: theme.colorScheme.surfaceContainerHighest),
                    widget.builder(context, _onCode),
                    // Marco de encuadre.
                    IgnorePointer(
                      child: FractionallySizedBox(
                        widthFactor: 0.7,
                        heightFactor: 0.7,
                        child: Container(
                          key: const Key('scanner.frame'),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.colorScheme.primary, width: 3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text('Apunta al código QR', textAlign: TextAlign.center, style: theme.textTheme.titleSmall),
            const SizedBox(height: 18),
            // Alternativa sin cámara (escritorio, QR dañado): el texto pegado pasa por el mismo DeepLinkParser.
            LabeledField(
              label: 'O pega el enlace del QR',
              child: TextField(
                key: const Key('scanner.paste'),
                controller: _pasted,
                decoration: InputDecoration(
                  hintText: 'Enlace o referencia',
                  suffixIcon: TextButton(
                    key: const Key('scanner.paste.clipboard'),
                    onPressed: _paste,
                    child: const Text('Pegar'),
                  ),
                ),
                onSubmitted: (v) => v.trim().isEmpty ? null : _onCode(v.trim()),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('scanner.paste.open'),
              onPressed: () => _pasted.text.trim().isEmpty ? null : _onCode(_pasted.text.trim()),
              child: const Text('Abrir enlace'),
            ),
            const SizedBox(height: 12),
            Text(
              'Para seguir una donación, escribe o pega su código en Seguir una donación.',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
