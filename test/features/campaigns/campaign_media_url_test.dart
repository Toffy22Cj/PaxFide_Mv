import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/features/campaigns/data/campaign_api.dart';

import '../../support/fakes.dart';

void main() {
  group('resolveApiMediaUrl', () {
    final baseWithoutSlash = Uri.parse('http://api.test:8080/api/v1');
    final baseWithSlash = Uri.parse('https://api.paxfide.org/');
    final baseWithoutPort = Uri.parse('https://api.paxfide.org');

    test('devuelve la URL esperada con ruta válida y base con puerto y ruta previa', () {
      final resolved = resolveApiMediaUrl(baseWithoutSlash, '/api/v1/public/campaigns/PUB1/cover');
      expect(resolved, Uri.parse('http://api.test:8080/api/v1/public/campaigns/PUB1/cover'));
    });

    test('maneja apiBaseUrl con o sin barra final', () {
      final withSlash = resolveApiMediaUrl(baseWithSlash, '/api/v1/public/campaigns/PUB1/logo');
      expect(withSlash, Uri.parse('https://api.paxfide.org/api/v1/public/campaigns/PUB1/logo'));

      final withoutSlash = resolveApiMediaUrl(baseWithoutPort, '/api/v1/public/campaigns/PUB1/logo');
      expect(withoutSlash, Uri.parse('https://api.paxfide.org/api/v1/public/campaigns/PUB1/logo'));
    });

    test('elimina parámetros de consulta y fragmentos (sin códigos de rastreo)', () {
      final resolved = resolveApiMediaUrl(
        baseWithoutPort,
        '/api/v1/public/campaigns/PUB1/cover?utm_source=test&tracker=123#fragment',
      );
      expect(resolved, Uri.parse('https://api.paxfide.org/api/v1/public/campaigns/PUB1/cover'));
      expect(resolved?.hasQuery, isFalse);
    });

    test('rechaza rutas que no empiezan por /api/v1/public/', () {
      expect(resolveApiMediaUrl(baseWithoutPort, '/api/v1/auth/me'), isNull);
      expect(resolveApiMediaUrl(baseWithoutPort, '/public/campaigns/PUB1/cover'), isNull);
      expect(resolveApiMediaUrl(baseWithoutPort, 'api/v1/public/campaigns/PUB1/cover'), isNull);
      expect(resolveApiMediaUrl(baseWithoutPort, '/api/v1/private/doc'), isNull);
    });

    test('rechaza rutas externas o con autoridad', () {
      expect(resolveApiMediaUrl(baseWithoutPort, 'https://malicious.com/api/v1/public/cover'), isNull);
      expect(resolveApiMediaUrl(baseWithoutPort, 'http://malicious.com/api/v1/public/cover'), isNull);
      expect(resolveApiMediaUrl(baseWithoutPort, '//malicious.com/api/v1/public/cover'), isNull);
    });

    test('devuelve null con null o vacío', () {
      expect(resolveApiMediaUrl(null, '/api/v1/public/cover'), isNull);
      expect(resolveApiMediaUrl(baseWithoutPort, null), isNull);
      expect(resolveApiMediaUrl(baseWithoutPort, ''), isNull);
      expect(resolveApiMediaUrl(baseWithoutPort, '   '), isNull);
      expect(resolveApiMediaUrl(Uri.parse(''), '/api/v1/public/cover'), isNull);
    });
  });

  group('CampaignApi parseo de cover, logo y verificación', () {
    late FakeApiClient api;
    late CampaignApi campaignApi;

    setUp(() {
      api = FakeApiClient();
      campaignApi = CampaignApi(api);
    });

    test('discover() lee organizationVerified, organizationLogoUrl y coverImageUrl', () async {
      api.enqueue(
        const ApiResponse(
          statusCode: 200,
          data: {
            'items': [
              {
                'publicCode': 'PUB1',
                'title': 'Campaña 1',
                'organizationName': 'Fundación Pax',
                'status': 'OPEN',
                'organizationVerified': true,
                'organizationLogoUrl': '/api/v1/public/campaigns/PUB1/organization-logo',
                'coverImageUrl': '/api/v1/public/campaigns/PUB1/cover',
              },
              {
                'publicCode': 'PUB2',
                'title': 'Campaña 2',
                'organizationName': 'Asociación Demo',
                'status': 'OPEN',
                'organizationVerified': 'not_a_bool',
              },
            ],
          },
        ),
      );

      final (items, _) = await campaignApi.discover();
      expect(items, hasLength(2));

      final first = items[0];
      expect(first.organizationVerified, isTrue);
      expect(first.organizationLogoUrl, '/api/v1/public/campaigns/PUB1/organization-logo');
      expect(first.coverImageUrl, '/api/v1/public/campaigns/PUB1/cover');

      final second = items[1];
      expect(second.organizationVerified, isFalse);
      expect(second.organizationLogoUrl, isNull);
      expect(second.coverImageUrl, isNull);
    });

    test('get() lee organizationVerified, organizationLogoUrl y coverImageUrl', () async {
      api.enqueue(
        const ApiResponse(
          statusCode: 200,
          data: {
            'organizationName': 'Fundación Verificada',
            'title': 'Campaña Única',
            'status': 'OPEN',
            'startDate': '2026-10-01',
            'endDate': '2026-12-31',
            'organizationVerified': true,
            'organizationLogoUrl': '/api/v1/public/campaigns/PUB1/organization-logo',
            'coverImageUrl': '/api/v1/public/campaigns/PUB1/cover',
          },
        ),
      );

      final c = await campaignApi.get('PUB1');
      expect(c.organizationVerified, isTrue);
      expect(c.organizationLogoUrl, '/api/v1/public/campaigns/PUB1/organization-logo');
      expect(c.coverImageUrl, '/api/v1/public/campaigns/PUB1/cover');
    });

    test('get() con organizationVerified ausente o no booleano queda false', () async {
      api.enqueue(
        const ApiResponse(
          statusCode: 200,
          data: {
            'organizationName': 'Fundación No Verificada',
            'title': 'Campaña 2',
            'status': 'OPEN',
            'startDate': '2026-10-01',
            'endDate': '2026-12-31',
          },
        ),
      );

      final c = await campaignApi.get('PUB2');
      expect(c.organizationVerified, isFalse);
      expect(c.organizationLogoUrl, isNull);
      expect(c.coverImageUrl, isNull);
    });
  });
}
