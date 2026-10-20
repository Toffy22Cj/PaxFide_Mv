import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/features/donations/domain/receipt.dart';
import 'package:paxfide_mobile/features/donations/presentation/receipt_view.dart';

void main() {
  testWidgets('M-22: comprobante (no certificado) con importe, convocatoria y número', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReceiptView(
            receipt: const DonationReceipt(
              receiptNumber: 'R-001',
              campaignTitle: 'Abrigo',
              organizationName: 'Fundación Demo',
              amount: '4000000',
              currency: 'COP',
              confirmedAt: '2026-10-07T10:00:00Z',
            ),
          ),
        ),
      ),
    );
    expect(find.text('Comprobante de donación'), findsOneWidget);
    expect(find.text('40 000,00 COP'), findsOneWidget);
    expect(find.text('Comprobante n.º R-001'), findsOneWidget);
    expect(find.textContaining('no es un certificado tributario'), findsOneWidget);
  });

  test('M-22: sin backend ni dependencia para compartir, no se ofrece', () {
    expect(const UnavailableReceiptSource().isAvailable, isFalse);
    expect(const UnavailableReceiptSharer().isAvailable, isFalse);
  });
}
