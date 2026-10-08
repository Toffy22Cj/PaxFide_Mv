import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/shared/quantity.dart';

/// Cantidades del backend: texto decimal con escala 4 ("10.0000"). Sin ceros sobrantes y sin redondeo.
void main() {
  test('quita solo los ceros sobrantes', () {
    expect(formatQuantity('10.0000'), '10');
    expect(formatQuantity('2.5000'), '2,5');
    expect(formatQuantity('0.1250'), '0,125');
    expect(formatQuantity('1.0001'), '1,0001');
    expect(formatQuantity('100'), '100');
    expect(formatQuantity('100.'), '100');
  });

  test('nunca redondea', () {
    expect(formatQuantity('3.3333'), '3,3333');
    expect(formatQuantity('0.0001'), '0,0001');
  });

  test('lo que no es un decimal se muestra tal cual', () {
    expect(formatQuantity('abc'), 'abc');
    expect(formatQuantity(''), '');
  });

  test('con unidad', () {
    expect(formatQuantityWithUnit('10.0000', 'UNITS'), '10 UNITS');
    expect(formatQuantityWithUnit(null, 'kg'), 'kg');
    expect(formatQuantityWithUnit(null, null), '—');
  });
}
