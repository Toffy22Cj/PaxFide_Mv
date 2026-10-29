import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/features/donations/domain/payment_link.dart';

void main() {
  final web = Uri.parse('https://paxfide.example');
  final api = Uri.parse('https://api.paxfide.example/api/v1');
  bool ok(String u, {Uri? publicOrigin, Uri? apiBase}) =>
      isOpenablePaymentUrl(Uri.parse(u), publicOrigin: publicOrigin ?? web, apiBaseUrl: apiBase ?? api);

  test('S-02: https hacia la web o la API de PaxFide se abre', () {
    expect(ok('https://paxfide.example/demo/checkout/sim_1'), isTrue);
    expect(ok('https://api.paxfide.example/checkout'), isTrue);
  });

  test('S-02: otro host, otro esquema o http hacia fuera no se abren', () {
    expect(ok('https://otro.example/pago'), isFalse);
    expect(ok('intent://pago#Intent;scheme=x;end'), isFalse);
    expect(ok('paxfide://pago'), isFalse);
    expect(ok('http://paxfide.example/pago'), isFalse, reason: 'la web configurada es https');
    expect(ok('javascript:alert(1)'), isFalse);
  });

  test('demo en la red local: http solo hacia el mismo host configurado en http', () {
    final lan = Uri.parse('http://192.168.1.54:3000');
    expect(ok('http://192.168.1.54:3000/demo/checkout/1', publicOrigin: lan), isTrue);
    expect(ok('http://192.168.1.99/demo/checkout/1', publicOrigin: lan), isFalse);
  });
}
