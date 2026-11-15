import 'dart:typed_data';

import '../data/account_donations_api.dart';

/// M-22: comprobante de donación (no es un certificado tributario: ese lo expide la organización). El backend aún no
/// lo expone y compartir la imagen necesita una dependencia nueva (ver PENDIENTES_ADONIS.md).
class DonationReceipt {
  const DonationReceipt({
    required this.receiptNumber,
    required this.campaignTitle,
    required this.organizationName,
    required this.amount,
    required this.currency,
    required this.confirmedAt,
  });
  final String receiptNumber;
  final String campaignTitle;
  final String organizationName;
  final String amount;
  final String currency;
  final String confirmedAt;
}

abstract interface class ReceiptSource {
  /// Falso mientras no exista el endpoint: la app no ofrece el comprobante.
  bool get isAvailable;
  Future<DonationReceipt?> receiptFor(AccountDonation donation);
}

class UnavailableReceiptSource implements ReceiptSource {
  const UnavailableReceiptSource();

  @override
  bool get isAvailable => false;

  @override
  Future<DonationReceipt?> receiptFor(AccountDonation donation) async => null;
}

/// Comparte la imagen PNG del comprobante con otras apps del teléfono.
abstract interface class ReceiptSharer {
  bool get isAvailable;
  Future<void> sharePng(Uint8List png, {required String fileName});
}

class UnavailableReceiptSharer implements ReceiptSharer {
  const UnavailableReceiptSharer();

  @override
  bool get isAvailable => false;

  @override
  Future<void> sharePng(Uint8List png, {required String fileName}) async {}
}
