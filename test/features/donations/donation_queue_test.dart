import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/core/offline/command_outcome.dart';
import 'package:paxfide_mobile/features/donations/data/donation_intent_api.dart';
import 'package:paxfide_mobile/features/donations/domain/donation_queue.dart';

import '../../support/fakes.dart';

/// Enmienda 4 de ADR-043, S5: donar sin conexión.
void main() {
  late FakeApiClient api;
  late InMemorySecureKeyValueStore secure;
  late DonationQueue queue;
  String? account;

  SavedDonation donation(String id, {String? accountId, int day = 1}) => SavedDonation(
    commandId: id,
    publicCode: 'PUB-1',
    campaignTitle: 'Abrigo para el invierno',
    amount: '5000000',
    currency: 'COP',
    accountId: accountId,
    createdAt: DateTime.utc(2026, 11, day),
  );

  setUp(() {
    api = FakeApiClient();
    secure = InMemorySecureKeyValueStore();
    account = 'acc-1';
    queue = DonationQueue(secure, DonationIntentApi(api), sessionAccountId: () => account);
  });

  test('se envía sola con su Command-Id; guarda intentId, statusToken y enlace de pago, nunca el código', () async {
    await queue.save(donation('cmd-1', accountId: 'acc-1'));
    api.enqueue(
      const ApiResponse(
        statusCode: 201,
        data: {'intentId': 'i-1', 'statusToken': 'tok-1', 'paymentRedirectUrl': '/pagar/i-1'},
      ),
    );
    await queue.sendAll();
    final call = api.calls.single;
    expect(call.path, '/public/campaigns/PUB-1/donation-intents');
    expect(call.headers['Command-Id'], 'cmd-1');
    expect(call.credentialMode, CredentialMode.jwt);
    expect(call.body, {'amount': '5000000', 'currency': 'COP', 'paymentMethod': 'GATEWAY'});
    final saved = (await queue.visible()).single;
    expect(saved.status, SavedDonationStatus.sent);
    expect(saved.statusToken, 'tok-1');
    expect(saved.paymentUrl, '/pagar/i-1');

    api.enqueue(const ApiResponse(statusCode: 200, data: {'status': 'CONFIRMED', 'trackingCode': 'COD-SECRETO'}));
    final st = await queue.status(saved);
    expect(st.trackingCode, 'COD-SECRETO');
    expect(api.calls.last.headers['Intent-Token'], 'tok-1');
    expect(secure.values.values.join(), isNot(contains('COD-SECRETO')));
  });

  test('sin red sigue pendiente; un fallo ambiguo también (se reenvía con el mismo Command-Id)', () async {
    await queue.save(donation('cmd-1'));
    api.enqueue(const ConnectionNotEstablishedException());
    await queue.sendAll();
    api.enqueue(const NetworkTimeoutException());
    await queue.sendAll();
    expect((await queue.visible()).single.status, SavedDonationStatus.pending);
    expect(api.calls.map((c) => c.headers['Command-Id']).toSet(), {'cmd-1'});
    expect(api.calls.every((c) => c.credentialMode == CredentialMode.none), isTrue, reason: 'sin cuenta, sin JWT');
  });

  test('rechazada (4xx): queda fallida y no se reintenta', () async {
    await queue.save(donation('cmd-1'));
    api.enqueue(const ApiResponse(statusCode: 409));
    await queue.sendAll();
    await queue.sendAll();
    expect((await queue.visible()).single.status, SavedDonationStatus.failed);
    expect(api.calls, hasLength(1));
  });

  test('H2: la de una cuenta no la ve ni la envía otra; las sin cuenta, sí', () async {
    await queue.save(donation('cmd-a', accountId: 'acc-1'));
    await queue.save(donation('cmd-anon', day: 2));
    account = 'acc-2';
    expect((await queue.visible()).map((d) => d.commandId), ['cmd-anon']);
    api.enqueue(const ApiResponse(statusCode: 201, data: {'intentId': 'i-9', 'statusToken': 't'}));
    await queue.sendAll();
    expect(api.calls.single.headers['Command-Id'], 'cmd-anon');
    expect(await queue.send(donation('cmd-a', accountId: 'acc-1')), CommandOutcome.notSent);
  });
}
