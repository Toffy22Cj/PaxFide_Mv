import '../data/account_donations_api.dart';

/// Un logro del donante (M-23). Solo lo ve el propio donante en "Mis donaciones"; no se comparte.
class Achievement {
  const Achievement(this.id, this.title, this.howTo, {required this.unlocked});
  final String id;
  final String title;
  final String howTo;
  final bool unlocked;
}

/// Logros derivados solo de las donaciones que la app ya recibe (`GET /account/donations`), sin endpoints nuevos.
/// Cuentan las donaciones con pago confirmado.
List<Achievement> achievementsFor(List<AccountDonation> donations) {
  final confirmed = donations.where((d) => d.status == 'CONFIRMED').toList();
  final causes = confirmed.map((d) => d.campaignTitle).where((t) => t.isNotEmpty).toSet().length;
  return [
    Achievement('first', 'Primera donación', 'Haz tu primera donación', unlocked: confirmed.isNotEmpty),
    Achievement('steady', 'Donante constante', 'Dona 3 veces', unlocked: confirmed.length >= 3),
    Achievement('causes', 'Varias causas', 'Apoya 2 causas distintas', unlocked: causes >= 2),
    Achievement('big-heart', 'Gran corazón', 'Dona 10 veces', unlocked: confirmed.length >= 10),
  ];
}
