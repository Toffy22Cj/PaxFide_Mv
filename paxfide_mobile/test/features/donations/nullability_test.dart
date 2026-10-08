import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/features/donations/data/donation_intent_api.dart';

/// referencia-api-v1 (develop 5fb1eb1, revisión de nulabilidad del 2026-10-08): `campo?` puede faltar o llegar null.
void main() {
  test('CV-11: statusToken y paymentRedirectUrl pueden faltar o ser null', () {
    final a = DonationIntentApi.parseCreated({'intentId': 'i-1'});
    expect(a.intentId, 'i-1');
    expect(a.statusToken, isNull);
    expect(a.paymentRedirectUrl, isNull);
    final b = DonationIntentApi.parseCreated({'intentId': 'i-1', 'statusToken': null, 'paymentRedirectUrl': null});
    expect(b.statusToken, isNull);
  });

  test('CV-11: sin intentId → mal formada', () {
    expect(() => DonationIntentApi.parseCreated({'statusToken': 't'}), throwsA(isA<MalformedResponseException>()));
  });
}
