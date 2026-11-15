import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/caching_api_client.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';

import '../support/fakes.dart';

/// Enmienda 4 de ADR-043, S2: lecturas sin conexión.
void main() {
  late FakeApiClient inner;
  late InMemorySecureKeyValueStore secure;
  late CachingApiClient api;
  String? account = 'acc-1';

  setUp(() {
    inner = FakeApiClient();
    secure = InMemorySecureKeyValueStore();
    account = 'acc-1';
    api = CachingApiClient(inner, secure, accountId: () => account);
  });

  const ok = ApiResponse(statusCode: 200, data: {'items': ['a']});

  test('con red guarda; sin red devuelve lo guardado y marca offline; al volver la red, lo desmarca', () async {
    inner.enqueue(ok);
    expect((await api.get('/account/donations', credentialMode: CredentialMode.jwt)).data, ok.data);
    expect(api.offline.value, isFalse);

    inner.enqueue(const ConnectionNotEstablishedException());
    final cached = await api.get('/account/donations', credentialMode: CredentialMode.jwt);
    expect(cached.data, ok.data);
    expect(cached.headers['x-paxfide-cached'], 'true');
    expect(api.offline.value, isTrue);

    inner.enqueue(ok);
    await api.get('/account/donations', credentialMode: CredentialMode.jwt);
    expect(api.offline.value, isFalse);
  });

  test('por cuenta: otra cuenta no ve lo guardado de la primera', () async {
    inner.enqueue(ok);
    await api.get('/account/donations', credentialMode: CredentialMode.jwt);
    account = 'acc-2';
    inner.enqueue(const NetworkTimeoutException());
    await expectLater(
      api.get('/account/donations', credentialMode: CredentialMode.jwt),
      throwsA(isA<NetworkTimeoutException>()),
    );
  });

  test('las públicas se guardan para cualquiera; la consulta forma parte de la clave', () async {
    inner.enqueue(ok);
    await api.get('/public/campaigns', queryParams: {'cursor': 'c1'}, credentialMode: CredentialMode.none);
    account = null;
    inner.enqueue(const ConnectionNotEstablishedException());
    expect(
      (await api.get('/public/campaigns', queryParams: {'cursor': 'c1'}, credentialMode: CredentialMode.none)).data,
      ok.data,
    );
    inner.enqueue(const ConnectionNotEstablishedException());
    await expectLater(
      api.get('/public/campaigns', credentialMode: CredentialMode.none),
      throwsA(isA<ConnectionNotEstablishedException>()),
    );
  });

  test('nunca guarda el seguimiento por código, lo que lleva cabeceras propias, /me ni los errores', () async {
    inner.enqueue(ok);
    await api.get('/donations/tracking', headers: {'Authorization': 'Bearer COD'}, credentialMode: CredentialMode.tracking);
    inner.enqueue(ok);
    await api.get('/public/donation-intents/i-1', headers: {'Intent-Token': 't'}, credentialMode: CredentialMode.none);
    inner.enqueue(ok);
    await api.get('/me', credentialMode: CredentialMode.jwt);
    inner.enqueue(const ApiResponse(statusCode: 403));
    await api.get('/physical-assets/A-1', credentialMode: CredentialMode.jwt);
    expect(secure.values.keys.where((k) => k.startsWith(CachingApiClient.prefix)), isEmpty);
    expect(secure.values.values.join(), isNot(contains('COD')));
  });

  test('sin JWT (la petición no salió por la sesión) no se sirve lo guardado', () async {
    inner.enqueue(ok);
    await api.get('/account/donations', credentialMode: CredentialMode.jwt);
    inner.enqueue(const MissingCredentialException());
    await expectLater(
      api.get('/account/donations', credentialMode: CredentialMode.jwt),
      throwsA(isA<MissingCredentialException>()),
    );
  });

  test('lo guardado nunca lleva el código de seguimiento ni tokens (ADR-043 §0)', () async {
    inner.enqueue(const ApiResponse(
      statusCode: 200,
      data: {
        'items': [
          {'intentId': 'i-1', 'trackingCode': 'COD-SECRETO', 'status': 'CONFIRMED'},
        ],
      },
    ));
    final live = await api.get('/account/donations', credentialMode: CredentialMode.jwt);
    expect((live.data!['items'] as List).first['trackingCode'], 'COD-SECRETO', reason: 'con red llega igual');
    expect(secure.values.values.join(), isNot(contains('COD-SECRETO')));
    inner.enqueue(const ConnectionNotEstablishedException());
    final cached = await api.get('/account/donations', credentialMode: CredentialMode.jwt);
    expect((cached.data!['items'] as List).first, {'intentId': 'i-1', 'status': 'CONFIRMED'});
  });
}
