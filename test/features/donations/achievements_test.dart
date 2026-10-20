import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/features/donations/data/account_donations_api.dart';
import 'package:paxfide_mobile/features/donations/domain/achievements.dart';

AccountDonation d(String title, String status) =>
    AccountDonation(campaignTitle: title, amount: '1000', currency: 'COP', status: status);

void main() {
  Set<String> unlocked(List<AccountDonation> ds) =>
      achievementsFor(ds).where((a) => a.unlocked).map((a) => a.id).toSet();

  test('sin donaciones confirmadas no hay logros (un pago fallido no cuenta)', () {
    expect(unlocked([d('Abrigo', 'FAILED'), d('Abrigo', 'PENDING')]), isEmpty);
  });

  test('primera, constante y varias causas', () {
    expect(unlocked([d('Abrigo', 'CONFIRMED')]), {'first'});
    expect(unlocked([d('Abrigo', 'CONFIRMED'), d('Abrigo', 'CONFIRMED'), d('Útiles', 'CONFIRMED')]), {
      'first',
      'steady',
      'causes',
    });
  });

  test('gran corazón con 10 donaciones confirmadas', () {
    expect(unlocked(List.generate(10, (_) => d('Abrigo', 'CONFIRMED'))), contains('big-heart'));
  });
}
