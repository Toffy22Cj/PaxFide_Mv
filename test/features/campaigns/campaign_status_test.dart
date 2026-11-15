import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/features/campaigns/domain/campaign_status.dart';

/// El backend deja la convocatoria OPEN después de su fecha de cierre: la app la muestra terminada.
void main() {
  final now = DateTime.utc(2026, 11, 12, 12);

  test('abierta antes del cierre; terminada al pasar la fecha aunque el backend diga OPEN', () {
    expect(campaignOpen('OPEN', '2026-11-12T13:00:00Z', now: now), isTrue);
    expect(campaignOpen('OPEN', '2026-11-11T05:55:00Z', now: now), isFalse);
    expect(effectiveCampaignStatus('OPEN', '2026-11-11T05:55:00Z', now: now), 'ENDED');
    expect(effectiveCampaignStatus('OPEN', '2026-12-01', now: now), 'OPEN');
    expect(effectiveCampaignStatus('CLOSED', '2026-12-01', now: now), 'CLOSED');
  });

  test('una fecha que no se puede leer no da la convocatoria por terminada', () {
    expect(campaignEnded('', now: now), isFalse);
    expect(campaignOpen('OPEN', 'no-es-fecha', now: now), isTrue);
  });
}
