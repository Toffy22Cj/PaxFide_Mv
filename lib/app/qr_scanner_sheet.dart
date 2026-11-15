import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../shared/widgets/pax_ui.dart';
import '../features/auth/domain/session_state.dart';
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
          child: Text('La cámara no está disponible en este equipo. Usa el campo de abajo.'),
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
///
/// Según el perfil (solo presentación: el guard no mira roles y el permiso lo decide el backend, P7):
/// - **Empleado** (E-02): lee lotes y convocatorias, y deja pegar o escribir la referencia de un lote, que abre su
///   ficha (DDM-16).
/// - **Donante o sin sesión:** solo enlaces de PaxFide. Un texto suelto nunca abre una ficha (un código de
///   seguimiento pegado ahí no puede acabar en una ruta, ADR-043 §0). El QR de un lote, para el donante, da un aviso
///   y no se abre; sin sesión sigue R2 (Entrar y luego la ficha), porque puede ser un empleado sin sesión.
/// Lo que no se reconoce lleva, además del aviso, a «Seguir una donación».
Future<void> scanQr(BuildContext context) async {
  final services = AppScope.of(context);
  final employee = services.session.principal?.showsOperatorActions ?? false;
  final raw = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ScannerSheet(builder: services.qrScannerBuilder, employee: employee),
    ),
  );
  if (raw == null || !context.mounted) return;
  await handleScannedCode(context, raw);
}

/// Lo que se hace con un código leído o pegado, venga de la hoja o de la pestaña Escanear.
Future<void> handleScannedCode(BuildContext context, String raw) async {
  final services = AppScope.of(context);
  final employee = services.session.principal?.showsOperatorActions ?? false;
  // E-02: una referencia escrita a mano (sin enlace) abre la ficha del lote. Solo en el escáner del empleado.
  if (employee && AppRoutes.isValidParam(raw) && !raw.contains(':')) {
    services.router.push(AppRoutes.assetPath(raw));
    return;
  }
  final link = services.deepLinkParser.parseText(raw);
  final signedIn = services.session.state.status == SessionStatus.authenticated;
  if (link.isApproved && link.category == RouteCategory.authenticated && signedIn && !employee) {
    _notice(context, 'Este QR es de un lote de una organización: solo lo abren sus empleados.');
    return;
  }
  final opened = link.isApproved && await services.router.openDeepLink(link);
  if (!opened && context.mounted) {
    final reason = services.config.publicOrigin == null
        ? 'La app no tiene configurado el origen de los enlaces de PaxFide.'
        : 'Este código QR no es un enlace de PaxFide reconocido.';
    _notice(context, reason, toTracking: !employee);
  }
}

/// Aviso del escáner. [toTracking]: sin callejón sin salida, lleva a «Seguir una donación».
void _notice(BuildContext context, String text, {bool toTracking = false}) {
  final services = AppScope.of(context);
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(text),
      action: toTracking
          ? SnackBarAction(label: 'Seguir una donación', onPressed: () => services.router.push(AppRoutes.tracking))
          : null,
    ),
  );
}

class _ScannerSheet extends StatelessWidget {
  const _ScannerSheet({required this.builder, required this.employee});
  final QrScannerBuilder builder;
  final bool employee;

  @override
  Widget build(BuildContext context) => Scaffold(
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
      child: ScannerPanel(builder: builder, employee: employee, onCode: (raw) => Navigator.of(context).pop(raw)),
    ),
  );
}

/// El escáner con su alternativa de pegar o escribir: en la hoja (donante, login) y en la pestaña Escanear del
/// empleado. Entrega el primer código leído; [resetKey] distinto vuelve a aceptar otro.
class ScannerPanel extends StatefulWidget {
  const ScannerPanel({super.key, required this.builder, required this.employee, required this.onCode});
  final QrScannerBuilder builder;

  /// Escáner del empleado (lotes y referencia escrita) o del donante (convocatorias).
  final bool employee;
  final ValueChanged<String> onCode;

  @override
  State<ScannerPanel> createState() => _ScannerPanelState();
}

class _ScannerPanelState extends State<ScannerPanel> {
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
    widget.onCode(raw);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.employee ? 'Lote o convocatoria' : 'Convocatoria',
          style: theme.textTheme.labelMedium?.copyWith(color: muted),
        ),
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
          label: widget.employee ? 'Pegar o escribir la referencia' : 'O pega el enlace de la convocatoria',
          child: TextField(
            key: const Key('scanner.paste'),
            controller: _pasted,
            decoration: InputDecoration(
              hintText: widget.employee ? 'Enlace o referencia del lote' : 'Enlace',
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
          child: Text(widget.employee ? 'Abrir' : 'Abrir enlace'),
        ),
        const SizedBox(height: 12),
        Text(
          'Para seguir una donación, escribe o pega su código en Seguir una donación.',
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    );
  }
}
