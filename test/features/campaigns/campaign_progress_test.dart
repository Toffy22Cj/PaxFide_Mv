import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/features/campaigns/domain/campaign_progress.dart';

void main() {
  final now = DateTime.utc(2026, 10, 20, 12);

  test('porcentaje, días que quedan y meta alcanzada', () {
    final p = CampaignProgress.of(target: 1000, cleared: 425, endDate: '2026-10-30T12:00:00Z', now: now);
    expect(p.percentText, '42 % de la meta');
    expect(p.daysText, 'Quedan 10 días');
    expect(p.reached, isFalse);

    final done = CampaignProgress.of(target: 1000, cleared: 1500, endDate: '2026-10-21T13:00:00Z', now: now);
    expect(done.fraction, 1.0);
    expect(done.reached, isTrue);
    expect(done.daysText, 'Queda 1 día');
  });

  test('terminada, termina hoy, menos del 1 % y sin meta', () {
    expect(CampaignProgress.of(endDate: '2026-10-19T00:00:00Z', now: now).daysText, 'Ya terminó');
    expect(CampaignProgress.of(endDate: '2026-10-20T20:00:00Z', now: now).daysText, 'Termina hoy');
    expect(
      CampaignProgress.of(target: 100000, cleared: 50, endDate: '', now: now).percentText,
      'Menos del 1 % de la meta',
    );
    expect(CampaignProgress.of(cleared: 50, endDate: '', now: now).percentText, isNull);
  });
}
