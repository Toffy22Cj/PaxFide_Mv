import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/features/tracking/data/tracking_api.dart';

IntegrityBatch _b(String result, {String? reason, bool? affects}) => IntegrityBatch(
  anchorStatus: 'ANCHORED',
  eventsOfThisDonation: 1,
  result: result,
  reason: reason,
  affectsThisDonation: affects,
);

IntegrityVerdict _v(List<IntegrityBatch> batches, {int unanchored = 0}) =>
    TrackingIntegrity(batches: batches, unanchoredEvents: unanchored, checkedAt: '').verdict;

void main() {
  test('sin lotes → pendiente', () => expect(_v(const []), IntegrityVerdict.pending));
  test('todo coincide y nada sin sellar → verificado', () => expect(_v([_b('MATCH')]), IntegrityVerdict.verified));
  test('coincide pero quedan registros sin sellar → parcial', () {
    expect(_v([_b('MATCH')], unanchored: 2), IntegrityVerdict.partial);
    expect(_v([_b('MATCH'), _b('INCONCLUSIVE', reason: 'NOT_ANCHORED')]), IntegrityVerdict.partial);
  });
  test('un lote sin anclar todavía no es "no comprobable"', () {
    expect(_v([_b('INCONCLUSIVE', reason: 'NOT_ANCHORED')]), IntegrityVerdict.pending);
  });
  test('no comprobable por otra causa → inconcluso', () {
    expect(_v([_b('MATCH'), _b('INCONCLUSIVE', reason: 'VERIFICATION_INCONCLUSIVE')]), IntegrityVerdict.inconclusive);
  });
  test('una diferencia manda, salvo que el servidor diga que no afecta a esta donación', () {
    expect(_v([_b('MATCH'), _b('MISMATCH', reason: 'ROOT_MISMATCH')]), IntegrityVerdict.mismatch);
    expect(_v([_b('MATCH'), _b('MISMATCH', reason: 'ROOT_MISMATCH', affects: false)]), IntegrityVerdict.partial);
  });
}
