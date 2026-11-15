import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/features/physical_assets/data/physical_asset_api.dart';
import 'package:paxfide_mobile/features/physical_assets/domain/asset_labels.dart';

/// Lo que ve una persona en lugar de los códigos del backend.
void main() {
  test('tipos conocidos en español; los demás, sin guiones ni mayúsculas sostenidas', () {
    expect(assetTypeLabel('FOOD_KIT'), 'Kit de alimentos');
    expect(assetTypeLabel('BLANKET'), 'Cobijas');
    expect(assetTypeLabel('CAMPING_TENT'), 'Camping tent');
    expect(assetTypeLabel(null), 'Activo');
  });

  test('cantidad con su unidad en español, en singular o plural', () {
    expect(quantityLabel('20.0000', 'UNITS'), '20 unidades');
    expect(quantityLabel('1', 'UNITS'), '1 unidad');
    expect(quantityLabel('2.5', 'KG'), '2,5 kg');
    expect(quantityLabel('3', 'SACOS'), '3 sacos');
  });

  test('lugares escritos a mano, legibles', () {
    expect(humanize('centro-comunitario'), 'Centro comunitario');
    expect(humanize('transportista-2'), 'Transportista 2');
  });

  test('el título del activo nunca es su código', () {
    const a = PhysicalAssetDto(
      assetRef: 'c435e659-38b7-55ee-bcde-0e3a88730454',
      lifecycleStatus: 'DISPATCHED',
      assetType: 'FOOD_KIT',
      quantity: '20.0000',
      unitOfMeasure: 'UNITS',
    );
    expect(assetTitle(a), 'Kit de alimentos · 20 unidades');
    expect(shortRef(a.assetRef), 'c435e659');
  });
}
