import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Muestra un QR con su URL debajo (para comprobar a simple vista qué contiene).
Future<void> showQrSheet(BuildContext context, {required String title, required Uri url}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (c) => SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 16),
          ColoredBox(
            color: Colors.white,
            child: QrImageView(
              key: const Key('qr.image'),
              data: url.toString(),
              size: 260,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(url.toString(), key: const Key('qr.url'), textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
