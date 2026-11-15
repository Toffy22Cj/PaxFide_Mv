import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/pax_tokens.dart';

/// Un QR con su URL debajo (para comprobar a simple vista qué contiene) y «Copiar enlace», dentro de la pantalla que
/// lo ofrece: sin icono ni hoja aparte (corrección 7: un toque menos).
class QrPanel extends StatelessWidget {
  const QrPanel({super.key, required this.title, required this.url, this.detail});

  final String title;
  final Uri url;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            if (detail != null) ...[
              const SizedBox(height: 4),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),
            // Fondo blanco siempre, también en modo oscuro: los lectores de QR lo necesitan.
            ColoredBox(
              color: PaxTokens.white,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: QrImageView(
                  key: const Key('qr.image'),
                  data: url.toString(),
                  size: 200,
                  backgroundColor: PaxTokens.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                  semanticsLabel: '$title: ${url.toString()}',
                ),
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(url.toString(), key: const Key('qr.url'), textAlign: TextAlign.center),
            TextButton.icon(
              key: const Key('qr.copy'),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copiar enlace'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url.toString()));
                if (context.mounted) {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Enlace copiado.')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
