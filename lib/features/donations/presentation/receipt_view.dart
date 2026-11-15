import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../shared/money.dart';
import '../../../shared/widgets/pax_logo.dart';
import '../domain/receipt.dart';

/// M-22: comprobante dibujado como tarjeta; [ReceiptView.capture] lo convierte en PNG para compartirlo.
class ReceiptView extends StatelessWidget {
  ReceiptView({super.key, required this.receipt});
  final DonationReceipt receipt;
  final _boundary = GlobalKey();

  /// PNG del comprobante tal como se ve (null si todavía no se ha dibujado).
  Future<List<int>?> capture() async {
    final b = _boundary.currentContext?.findRenderObject();
    if (b is! RenderRepaintBoundary) return null;
    final image = await b.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final r = receipt;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      key: _boundary,
      child: Container(
        key: const Key('receipt'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const PaxLogo(size: 40),
                const SizedBox(width: 12),
                Expanded(child: Text('Comprobante de donación', style: text.titleMedium)),
              ],
            ),
            const Divider(height: 24),
            Text(formatMinorUnits(r.amount, r.currency), style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(r.campaignTitle),
            if (r.organizationName.isNotEmpty) Text(r.organizationName, style: text.bodySmall),
            const SizedBox(height: 8),
            Text('Pago confirmado el ${r.confirmedAt.split('T').first}', style: text.bodySmall),
            Text('Comprobante n.º ${r.receiptNumber}', style: text.bodySmall),
            const SizedBox(height: 8),
            Text(
              'Este comprobante no es un certificado tributario; ese lo expide la organización.',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
