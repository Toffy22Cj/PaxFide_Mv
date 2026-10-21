import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../../app/app_services.dart';
import '../../../app/public_links.dart';
import '../../../shared/theme/pax_tokens.dart';

/// `/assets/:assetRef/qr` (E-11): el QR del activo a pantalla completa, con el brillo al máximo mientras se muestra y
/// la referencia en texto. El QR lleva la misma URL que la web (origen + `/assets/{assetRef}`); sin origen
/// configurado, solo la referencia (el escáner de la app abre las dos).
class AssetQrScreen extends StatefulWidget {
  const AssetQrScreen({super.key, required this.assetRef});
  final String assetRef;

  @override
  State<AssetQrScreen> createState() => _AssetQrScreenState();
}

class _AssetQrScreenState extends State<AssetQrScreen> {
  @override
  void initState() {
    super.initState();
    _brightness(() => ScreenBrightness.instance.setApplicationScreenBrightness(1.0));
  }

  @override
  void dispose() {
    _brightness(() => ScreenBrightness.instance.resetApplicationScreenBrightness());
    super.dispose();
  }

  /// Sin el plugin (escritorio, pruebas) se muestra el QR igual, sin cambiar el brillo.
  static Future<void> _brightness(Future<void> Function() call) async {
    try {
      await call();
    } on Object {
      // sin control de brillo
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final data = PublicLinks(services.config.publicOrigin).asset(widget.assetRef)?.toString() ?? widget.assetRef;
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR del activo'),
        leading: IconButton(
          key: const Key('assetqr.close'),
          tooltip: 'Volver',
          icon: const Icon(Icons.close),
          onPressed: services.router.back,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final size = c.maxWidth.clamp(160.0, 420.0);
                    // Siempre negro sobre blanco, también en modo oscuro: es lo que mejor leen las cámaras.
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: PaxTokens.white, borderRadius: BorderRadius.circular(16)),
                      child: QrImageView(
                        key: const Key('assetqr.image'),
                        data: data,
                        size: size - 32,
                        backgroundColor: PaxTokens.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                        semanticsLabel: 'Código QR del activo ${widget.assetRef}',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                SelectableText(
                  widget.assetRef,
                  key: const Key('assetqr.ref'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text('Muéstralo para que lo escaneen.', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
