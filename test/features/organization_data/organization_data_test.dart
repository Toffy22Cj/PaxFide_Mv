// Enmienda 6 de ADR-043 (aprobada por Adonis el 2026-11-19), plan 5a de plan-tanda-2026-11-19.
// ESTAS PRUEBAS NO SE HAN EJECUTADO: el entorno donde se escribieron no tiene Flutter. Las corre Adonis
// (`flutter analyze` y `flutter test`) y pega la salida literal en el PR.
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/features/auth/domain/principal.dart';
import 'package:paxfide_mobile/features/organization_data/data/organization_data_api.dart';
import 'package:paxfide_mobile/features/organization_data/presentation/organization_data_charts.dart';

import '../../support/fakes.dart';

Map<String, dynamic> _row(String month, String amount, [String currency = 'COP']) => {
  'month': month,
  'currency': currency,
  'clearedAmount': amount,
};

Map<String, dynamic> _event(String type, String at, {Map<String, dynamic>? subject}) => {
  'type': type,
  'occurredAt': at,
  'subject': ?subject,
};

void main() {
  group('Quién ve qué (E6-2, E6-3), con las reglas del backend', () {
    Principal p(List<String> roles, {String? org = 'org-1'}) =>
        Principal(accountId: 'acc-1', organizationId: org, roles: roles.toSet());

    test('fondos: ADMINISTRATOR o EMPLOYEE; el REPRESENTATIVE no', () {
      expect(p(['ADMINISTRATOR']).showsFundsData, isTrue);
      expect(p(['EMPLOYEE']).showsFundsData, isTrue);
      expect(p(['REPRESENTATIVE']).showsFundsData, isFalse);
    });

    test('actividad: los tres roles', () {
      for (final r in ['ADMINISTRATOR', 'REPRESENTATIVE', 'EMPLOYEE']) {
        expect(p([r]).showsActivityData, isTrue, reason: r);
      }
    });

    test('el donante (sin organización o sin rol de la organización) no ve nada', () {
      expect(p(['DONOR'], org: null).showsOrganizationData, isFalse);
      expect(p([], org: null).showsOrganizationData, isFalse);
      expect(p([]).showsOrganizationData, isFalse);
      // sin organización, ni siquiera con rol: el backend la exige
      expect(p(['ADMINISTRATOR'], org: null).showsOrganizationData, isFalse);
    });

    test('el selector solo para ADMINISTRATOR y EMPLOYEE', () {
      expect(p(['ADMINISTRATOR']).choosesOrganizationCharts, isTrue);
      expect(p(['EMPLOYEE']).choosesOrganizationCharts, isTrue);
      expect(p(['REPRESENTATIVE']).choosesOrganizationCharts, isFalse);
    });
  });

  group('Fondos mensuales: los datos del gráfico (respuesta de demo-historico)', () {
    final funds = MonthlyFunds.fromJson({
      'timezone': 'America/Bogota',
      'items': [
        _row('2026-07', '0'),
        _row('2026-08', '150000'),
        _row('2026-09', '0'),
        _row('2026-10', '250050'),
        _row('2026-10', '999', 'USD'),
      ],
    });

    test('un mes vacío es 0, no null; cada moneda por separado, la de más importe primero', () {
      expect(monthlyCurrencies(funds), ['COP', 'USD']);
      final cop = monthlyData(funds, 'COP');
      expect(cop.categories, ['jul 2026', 'ago 2026', 'sep 2026', 'oct 2026']);
      expect(cop.series.single.values, [0.0, 150000.0, 0.0, 250050.0]);
      expect(cop.format(250050), '2 500,50 COP');
      // aserción negativa: las monedas nunca se suman
      expect(monthlyData(funds, 'USD').series.single.values, [999.0]);
      expect(cop.series.single.values.whereType<double>().reduce((a, b) => a + b), 400050.0);
    });

    test('el acumulado de las barras y su línea', () {
      final combo = monthlyCumulativeData(funds, 'COP');
      expect(combo.series[1].values, [0.0, 150000.0, 150000.0, 400050.0]);
      expect(combo.series[1].label, 'Acumulado de estos 4 meses');
    });

    test('sin fondos (items vacío): ninguna moneda y nada que dibujar', () {
      final empty = MonthlyFunds.fromJson({'items': <Object>[]});
      expect(monthlyCurrencies(empty), isEmpty);
      expect(monthlyData(empty, 'COP').isEmpty, isTrue);
    });

    test('una moneda desconocida no se escala: se dice en unidades mínimas', () {
      final odd = MonthlyFunds.fromJson({
        'items': [_row('2026-10', '500', 'XYZ')],
      });
      expect(monthlyData(odd, 'XYZ').format(500), contains('unidades mínimas'));
    });

    test('«2026-07» → «jul 2026»; algo que no es un mes se deja tal cual', () {
      expect(shortMonth('2026-12'), 'dic 2026');
      expect(shortMonth('2026-13'), '2026-13');
      expect(shortMonth('raro'), 'raro');
    });
  });

  group('Actividad: los datos del gráfico', () {
    final events = [
      for (final e in [
        ('ASSET_REGISTERED', '2026-11-01T15:00:00Z'),
        ('ASSET_DISPATCHED', '2026-11-01T16:00:00Z'),
        ('ASSET_DELIVERED', '2026-11-03T12:00:00Z'),
        ('FUNDS_CLEARED', '2026-11-03T13:00:00Z'),
        ('FUNDS_CLEARED', '2026-11-03T14:00:00Z'),
      ])
        ActivityEvent(type: e.$1, occurredAt: DateTime.parse(e.$2)),
    ];

    test('por tipo: en el orden de siempre, solo los tipos que hay, con su etiqueta', () {
      final d = activityByType(events);
      expect(d.categories, ['Lote registrado', 'Lote despachado', 'Lote entregado', 'Donación confirmada']);
      expect(d.series.single.values, [1.0, 1.0, 1.0, 2.0]);
      expect(d.format(1), '1 evento');
      expect(d.format(2), '2 eventos');
    });

    test('por día: el día sin eventos entre los cargados cuenta 0', () {
      final o = activityOverTime(events);
      expect(o.weekly, isFalse);
      expect(o.data.categories, ['1 nov', '2 nov', '3 nov']);
      expect(o.data.series.single.values, [2.0, 0.0, 3.0]);
    });

    test('el día se cuenta en Bogotá: las 03:00 UTC del día 2 son del día 1 (22:00)', () {
      expect(dayInBogota(DateTime.parse('2026-11-02T03:00:00Z')), '2026-11-01');
      expect(dayInBogota(DateTime.parse('2026-11-02T05:00:00Z')), '2026-11-02');
    });

    test('más de 31 días: por semana', () {
      final o = activityOverTime([
        ActivityEvent(type: 'ASSET_REGISTERED', occurredAt: DateTime.parse('2026-09-01T15:00:00Z')),
        ActivityEvent(type: 'ASSET_REGISTERED', occurredAt: DateTime.parse('2026-11-01T15:00:00Z')),
      ]);
      expect(o.weekly, isTrue);
      expect(o.data.unit, 'Semana');
      expect(o.data.categories.first, startsWith('sem. '));
      expect(o.data.series.single.values.whereType<double>().reduce((a, b) => a + b), 2.0);
    });

    test('por tipo y día: una serie por tipo; sin eventos, nada', () {
      expect(activityOverTime(events, byType: true).data.series.map((s) => s.key), [
        'ASSET_REGISTERED',
        'ASSET_DISPATCHED',
        'ASSET_DELIVERED',
        'FUNDS_CLEARED',
      ]);
      expect(activityOverTime(const []).data.isEmpty, isTrue);
      expect(activityByType(const []).isEmpty, isTrue);
    });
  });

  group('Las dos lecturas (OrganizationDataApi)', () {
    late FakeApiClient api;
    setUp(() => api = FakeApiClient());

    test('fondos: ruta, months=12, con la sesión de la cuenta, y se entiende el cuerpo del backend', () async {
      api.routes['GET /organizations/org-1/funds/monthly'] = (_) => ApiResponse(
        statusCode: 200,
        data: {
          'timezone': 'America/Bogota',
          'items': [_row('2026-10', '250050')],
          'truncated': true,
        },
      );
      final r = await OrganizationDataApi(api).fundsMonthly('org-1');
      expect(api.calls.single.path, '/organizations/org-1/funds/monthly');
      expect(api.calls.single.credentialMode, CredentialMode.jwt);
      expect(api.getQueries.single, {'months': '12'});
      expect(r.value.items.single.clearedAmount, '250050');
      expect(r.value.truncated, isTrue);
      expect(r.fromCache, isFalse);
    });

    test('el identificador de la organización va codificado en la ruta', () async {
      api.routes['GET /organizations/a%2Fb/funds/monthly'] = (_) =>
          const ApiResponse(statusCode: 200, data: {'items': <Object>[]});
      await OrganizationDataApi(api).fundsMonthly('a/b');
      expect(api.calls.single.path, '/organizations/a%2Fb/funds/monthly');
    });

    test('un cuerpo que no es lo del contrato → MalformedResponse, nunca un gráfico', () async {
      api.routes['GET /organizations/org-1/funds/monthly'] = (_) =>
          const ApiResponse(statusCode: 200, data: {'items': 'no-es-lista'});
      await expectLater(OrganizationDataApi(api).fundsMonthly('org-1'), throwsA(isA<MalformedResponseException>()));
      api.routes['GET /organizations/org-1/funds/monthly'] = (_) => const ApiResponse(
        statusCode: 200,
        data: {
          'items': [
            {'month': '2026-10', 'currency': 'COP'},
          ],
        },
      );
      await expectLater(OrganizationDataApi(api).fundsMonthly('org-1'), throwsA(isA<MalformedResponseException>()));
    });

    test('403 llega como ForbiddenException (otro rol, otra organización o inexistente: el mismo)', () async {
      api.routes['GET /organizations/org-1/funds/monthly'] = (_) => const ApiResponse(statusCode: 403);
      await expectLater(OrganizationDataApi(api).fundsMonthly('org-1'), throwsA(isA<ForbiddenException>()));
    });

    test('actividad: se piden páginas con el cursor hasta 100 eventos y se dice que hay más', () async {
      var page = 0;
      api.routes['GET /organizations/org-1/activity'] = (_) {
        page++;
        return ApiResponse(
          statusCode: 200,
          data: {
            'items': [
              for (var i = 0; i < 20; i++)
                _event('ASSET_REGISTERED', '2026-11-0${(page % 9) + 1}T15:00:00Z', subject: {'kind': 'ASSET', 'ref': 'a$i'}),
            ],
            'nextCursor': 'c$page',
          },
        );
      };
      final r = await OrganizationDataApi(api).activity('org-1');
      expect(r.value.events, hasLength(100));
      expect(r.value.more, isTrue);
      expect(api.calls, hasLength(5)); // 5 páginas de 20, ni una más
      expect(api.getQueries, [null, {'cursor': 'c1'}, {'cursor': 'c2'}, {'cursor': 'c3'}, {'cursor': 'c4'}]);
    });

    test('actividad: sin nextCursor se acaba, y no dice que hay más', () async {
      api.routes['GET /organizations/org-1/activity'] = (_) => ApiResponse(
        statusCode: 200,
        data: {
          'items': [
            _event('BATCH_ANCHORED', '2026-11-01T15:00:00Z')..['eventCount'] = 4,
          ],
        },
      );
      final r = await OrganizationDataApi(api).activity('org-1');
      expect(r.value.events.single.eventCount, 4);
      expect(r.value.events.single.subjectKind, isNull);
      expect(r.value.more, isFalse);
      expect(api.calls, hasLength(1));
    });

    test('lo que viene de lo guardado sin conexión lo dice, con su fecha', () async {
      api.routes['GET /organizations/org-1/funds/monthly'] = (_) => const ApiResponse(
        statusCode: 200,
        data: {'items': <Object>[]},
        headers: {'x-paxfide-cached': 'true', 'x-paxfide-cached-at': '2026-11-20T15:30:00.000Z'},
      );
      final r = await OrganizationDataApi(api).fundsMonthly('org-1');
      expect(r.fromCache, isTrue);
      expect(r.cachedAt, DateTime.utc(2026, 11, 20, 15, 30));
    });
  });
}
