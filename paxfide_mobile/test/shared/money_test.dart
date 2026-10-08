import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/shared/money.dart';

/// referencia-api-v1 §0: importes en unidades mínimas ISO 4217; COP con exponente 2:
/// "100000" son $1.000 COP. Se muestran en formato colombiano.
void main() {
  group('mostrar unidades mínimas', () {
    test('el ejemplo literal del contrato', () {
      expect(formatMinorUnits('100000', 'COP'), '\$1.000 COP');
    });

    test('valores reales del ensayo (meta de la convocatoria y donación)', () {
      expect(formatMinorUnits('50000000', 'COP'), '\$500.000 COP');
      expect(formatMinorUnits(6000000, 'COP'), '\$60.000 COP');
      expect(formatMinorUnits(150050, 'COP'), '\$1.500,50 COP');
      expect(formatMinorUnits(5, 'COP'), '\$0,05 COP');
      expect(formatMinorUnits(0, 'COP'), '\$0 COP');
    });

    test('moneda sin exponente conocido: nunca se inventa la escala', () {
      expect(formatMinorUnits('12345', 'XYZ'), '12345 (unidades mínimas de XYZ)');
      expect(formatMinorUnits('12345', null), '12345 (unidades mínimas)');
    });

    test('valor que no es un entero → se muestra tal cual', () {
      expect(formatMinorUnits('abc', 'COP'), 'abc COP');
    });
  });

  group('importe escrito por el donante → unidades mínimas', () {
    test('pesos enteros o con hasta dos decimales', () {
      expect(toMinorUnits('1000', 'COP'), '100000');
      expect(toMinorUnits('1000,5', 'COP'), '100050');
      expect(toMinorUnits('1000.50', 'COP'), '100050');
      expect(toMinorUnits('0,01', 'COP'), '1');
      expect(toMinorUnits('60000', 'COP'), '6000000');
      expect(toMinorUnits('1.000.000', 'COP'), '100000000');
      expect(toMinorUnits('\$ 50.000', 'COP'), '5000000');
      expect(toMinorUnits('1 000', 'COP'), '100000');
    });

    test('inválidos → null', () {
      for (final bad in ['', '0', '0,00', '-5', '1,234', '1e3', 'abc', '10,5,3']) {
        expect(toMinorUnits(bad, 'COP'), isNull, reason: bad);
      }
    });

    test('sin exponente conocido no se convierte', () {
      expect(toMinorUnits('100', 'XYZ'), isNull);
      expect(isKnownCurrency('COP'), isTrue);
      expect(isKnownCurrency('XYZ'), isFalse);
    });
  });
}
