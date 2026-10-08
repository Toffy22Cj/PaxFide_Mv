import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/features/physical_assets/data/physical_asset_api.dart';

/// Forma real comprobada contra el backend local (2026-10-07): tras DISPATCHED, `currentLocation` no viene
/// (el bien está en tránsito y el backend omite los nulos).
void main() {
  test('DISPATCHED sin currentLocation (respuesta real del backend) se interpreta', () {
    final dto = PhysicalAssetDto.fromJson({
      'assetRef': 'A-1',
      'lifecycleStatus': 'DISPATCHED',
      'currentCustodianRef': 'transportista-1',
      'quantity': '1.0000',
      'unitOfMeasure': 'UNITS',
      'campaignRef': 'c',
    });
    expect(dto.lifecycleStatus, 'DISPATCHED');
    expect(dto.currentLocation, isNull);
    expect(dto.currentCustodianRef, 'transportista-1');
  });

  test('sin assetRef o sin lifecycleStatus → respuesta mal formada', () {
    expect(
      () => PhysicalAssetDto.fromJson({'lifecycleStatus': 'REGISTERED'}),
      throwsA(isA<MalformedResponseException>()),
    );
    expect(() => PhysicalAssetDto.fromJson({'assetRef': 'A-1'}), throwsA(isA<MalformedResponseException>()));
  });
}
