// Recorrido contra el backend REAL en local (encargo §6; runbook-demo-local.md del backend).
//
// Se salta salvo que exista PAXFIDE_REAL_API (p. ej. http://127.0.0.1:8080/api/v1). Necesita además las variables
// del demo.env del backend: TRACEABILITY_DEMO_SEED_PASSWORD y TRACEABILITY_DEMO_WEBHOOK_SECRET. Nunca imprime
// secretos: tokens, códigos de seguimiento y firmas no salen en la salida.
//
// La preparación (verificar la organización, crear la convocatoria, liquidar el pago con el webhook simulado,
// asignar fondos y registrar el activo) es de la web o de procesos de demo, no de la app: se hace con peticiones
// directas. Todo lo que es de la app se ejercita con su propio código (AuthApi, SessionController, SyncEngine,
// AssetOperations, TrackingApi, CampaignApi, DonationFlow, AccountDonationsApi, PredictionApi).
@Tags(['backend-real'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/auth_response_handler.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/http_api_client.dart';
import 'package:paxfide_mobile/core/offline/command_outcome.dart';
import 'package:paxfide_mobile/core/offline/outbox_item.dart';
import 'package:paxfide_mobile/core/offline/outbox_status.dart';
import 'package:paxfide_mobile/core/offline/sync_engine.dart';
import 'package:paxfide_mobile/core/storage/outbox_store.dart';
import 'package:paxfide_mobile/core/storage/token_store.dart';
import 'package:paxfide_mobile/core/util/command_id.dart';
import 'package:paxfide_mobile/features/auth/data/auth_api.dart';
import 'package:paxfide_mobile/features/auth/domain/session_controller.dart';
import 'package:paxfide_mobile/features/auth/domain/session_state.dart';
import 'package:paxfide_mobile/features/campaigns/data/campaign_api.dart';
import 'package:paxfide_mobile/features/donations/data/account_donations_api.dart';
import 'package:paxfide_mobile/features/donations/data/donation_intent_api.dart';
import 'package:paxfide_mobile/features/donations/domain/donation_flow.dart';
import 'package:paxfide_mobile/features/physical_assets/data/physical_asset_api.dart';
import 'package:paxfide_mobile/features/physical_assets/domain/asset_action.dart';
import 'package:paxfide_mobile/features/physical_assets/domain/asset_command.dart';
import 'package:paxfide_mobile/features/physical_assets/domain/asset_operations.dart';
import 'package:paxfide_mobile/features/prediction/data/prediction_api.dart';
import 'package:paxfide_mobile/features/tracking/data/tracking_api.dart';
import 'package:paxfide_mobile/shared/money.dart';

import '../support/fakes.dart';

final env = Platform.environment;
final base = env['PAXFIDE_REAL_API'];

/// Una "instalación" de la app para una cuenta: su TokenStore, su ApiClient real y su sesión.
class Device {
  Device() {
    tokens = SecureTokenStore(InMemorySecureKeyValueStore());
    late SessionController s;
    api = HttpApiClient(
      baseUrl: Uri.parse(base!),
      tokenStore: tokens,
      authResponseHandler: AuthResponseHandler(tokenStore: tokens, onSessionLoggedOut: () => s.onUnauthorized()),
    );
    session = s = SessionController(tokenStore: tokens, authApi: AuthApi(api));
  }
  late final TokenStore tokens;
  late final HttpApiClient api;
  late final SessionController session;

  Future<void> login(String email) async {
    await session.restore();
    await session.login(email, env['TRACEABILITY_DEMO_SEED_PASSWORD']!);
  }
}

final ids = CommandIdGenerator();

Future<ApiResponse> post(Device d, String path, Map<String, dynamic> body, {bool command = true}) => d.api.post(
  path,
  body: body,
  headers: command ? {'Command-Id': ids.next()} : null,
  credentialMode: CredentialMode.jwt,
);

/// HMAC-SHA256 en hexadecimal con el openssl del sistema (sin dependencias nuevas; solo en este test local).
Future<String> sign(String secret, String message) async {
  final p = await Process.start('openssl', ['dgst', '-sha256', '-hmac', secret, '-hex']);
  p.stdin.write(message);
  await p.stdin.close();
  final out = await p.stdout.transform(utf8.decoder).join();
  await p.exitCode;
  return out.trim().split(' ').last;
}

void main() {
  if (base == null) {
    test('backend real', () {}, skip: 'Sin PAXFIDE_REAL_API: recorrido contra el backend real no ejecutado');
    return;
  }

  late Device platform, admin, representative, employee, donor;
  late String org, campaignRef, publicCode, assetRef, trackingCode;
  final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;

  setUpAll(() async {
    platform = Device();
    admin = Device();
    representative = Device();
    employee = Device();
    donor = Device();
  });

  test('0. registro con contraseña de menos de 12 caracteres → 400 (PasswordTooShort, develop 1b012da)', () async {
    await expectLater(
      AuthApi(Device().api).register('corta-$stamp@demo.paxfide.local', 'once-chars!'),
      throwsA(isA<BadRequestException>()),
    );
  });

  test('1. registro de cuenta (POST /auth/register) y login con /me; sin rol en el JWT', () async {
    final email = 'donante-movil-$stamp@demo.paxfide.local';
    await AuthApi(donor.api).register(email, env['TRACEABILITY_DEMO_SEED_PASSWORD']!);
    await donor.session.restore();
    await donor.session.login(email, env['TRACEABILITY_DEMO_SEED_PASSWORD']!);
    expect(donor.session.state.status, SessionStatus.authenticated);
    expect(donor.session.principal!.roles, isEmpty);
    expect(donor.session.principal!.showsOperatorActions, isFalse);
  });

  test('2. cuentas de la semilla: los roles salen de /me', () async {
    await platform.login('plataforma@demo.paxfide.local');
    await admin.login('administrador@demo.paxfide.local');
    await representative.login('representante@demo.paxfide.local');
    await employee.login('empleado@demo.paxfide.local');
    expect(admin.session.principal!.showsPrediction, isTrue);
    expect(representative.session.principal!.showsPrediction, isTrue);
    expect(employee.session.principal!.showsOperatorActions, isTrue);
    expect(employee.session.principal!.showsPrediction, isFalse);
    org = admin.session.principal!.organizationId!;
  });

  test('3. preparación (web/demo): organización verificada, convocatoria y empleado asignado', () async {
    final v = await platform.api.post('/platform/organizations/$org/verify', credentialMode: CredentialMode.jwt);
    expect([200, 409], contains(v.statusCode));
    final now = DateTime.now().toUtc();
    String iso(DateTime t) => '${t.toIso8601String().split('.').first}Z';
    final c = await post(admin, '/organizations/$org/campaigns', {
      'title': 'Convocatoria móvil $stamp',
      'description': 'Recorrido de paxfide-mobile contra el backend real',
      'visibility': 'PUBLIC',
      'startDate': iso(now.add(const Duration(seconds: 5))),
      'endDate': iso(now.add(const Duration(days: 60))),
      'configuration': {
        'acceptedDonationTypes': ['MONETARY', 'IN_KIND'],
        'acceptedPaymentMethods': ['GATEWAY'],
        'currency': 'COP',
        'targetAmount': '50000000',
        'targetPolicy': 'FLEXIBLE',
      },
    });
    expect(c.statusCode, 201, reason: 'crear convocatoria');
    campaignRef = c.data!['campaignRef'] as String;
    publicCode = c.data!['publicCode'] as String;
    final a = await post(admin, '/campaigns/$campaignRef/employees', {
      'employeeRef': employee.session.principal!.accountId,
    });
    expect([201, 409], contains(a.statusCode), reason: 'asignar empleado');
    await Future<void>.delayed(const Duration(seconds: 6)); // que empiece la convocatoria
  });

  test('4. convocatoria pública (CampaignApi) y su narrativa con hechos', () async {
    final c = await CampaignApi(donor.api).get(publicCode);
    expect(c.status, 'OPEN');
    expect(c.currency, 'COP');
    // Unidades mínimas ISO 4217: la meta creada como "50000000" son 500 000,00 COP.
    expect(c.targetAmount, '50000000');
    expect(formatMinorUnits(c.targetAmount!, c.currency), '500 000,00 COP');
    final n = await CampaignApi(donor.api).narrative(publicCode);
    expect(['AVAILABLE', 'PENDING', 'UNAVAILABLE'], contains(n.status));
    expect(n.facts, isNotNull);
  });

  test('5. donar con cuenta (DonationFlow, CV-11 con JWT) y consultar con Intent-Token hasta el código', () async {
    final flow = DonationFlow(DonationIntentApi(donor.api));
    // El donante escribe 60000 pesos; la app envía unidades mínimas.
    final attempt = flow.start(publicCode, toMinorUnits('60000', 'COP')!, 'COP');
    expect(attempt.amount, '6000000');
    final (outcome, status) = await flow.create(attempt, withAccount: true);
    expect(outcome, CommandOutcome.acknowledged, reason: 'HTTP $status');

    // Reenvío con el mismo Command-Id: misma intención, token nuevo (DD-18 sustituida).
    final again = await flow.create(attempt, withAccount: true);
    expect(again.$1, CommandOutcome.acknowledged);

    // Pago simulado: lo dispara la web de demo con el webhook firmado (fuera de la app).
    final session = attempt.intent!.paymentRedirectUrl.split('/').last;
    final event = {
      'type': 'payment.confirmed',
      'paymentSessionId': session,
      'providerEventId': 'evt-${ids.next()}',
      'amount': '6000000',
      'currency': 'COP',
    };
    final sig = await sign(env['TRACEABILITY_DEMO_WEBHOOK_SECRET']!, jsonEncode(event));
    final hook = await Device().api.post(
      '/webhooks/payments',
      body: event,
      headers: {'X-Simulated-Signature': sig},
      credentialMode: CredentialMode.none,
    );
    expect(hook.statusCode, 200, reason: 'webhook simulado');

    IntentStatus? s;
    for (var i = 0; i < 30 && (s?.trackingCode == null); i++) {
      s = await flow.refresh(attempt);
      if (s.trackingCode == null) await Future<void>.delayed(const Duration(seconds: 1));
    }
    expect(s!.status, 'CONFIRMED');
    expect(s.trackingCode, isNotNull);
    trackingCode = s.trackingCode!;
  });

  test('6. mis donaciones (GET /account/donations) incluye la donación con cuenta', () async {
    final list = await AccountDonationsApi(donor.api).list();
    expect(list.map((d) => d.campaignTitle), contains('Convocatoria móvil $stamp'));
  });

  test('7. seguimiento con el código en la cabecera (TrackingApi); código inválido → mensaje único', () async {
    final t = await TrackingApi(Device().api).summary(trackingCode);
    expect(t.financial.originalAmount, 6000000);
    expect(formatMinorUnits(t.financial.originalAmount, t.financial.currency), '60 000,00 COP');
    final n = await TrackingApi(Device().api).narrative(trackingCode);
    expect(['AVAILABLE', 'PENDING'], contains(n.status));
    await expectLater(
      TrackingApi(Device().api).summary('no-es-un-codigo'),
      throwsA(isA<InvalidTrackingCodeException>()),
    );
  });

  test('8. preparación (web): fondos, asignación y registro del activo por el empleado', () async {
    final funds = (await admin.api.get('/organizations/$org/funds', credentialMode: CredentialMode.jwt)).requireData();
    final fund = (funds['items'] as List).cast<Map>().firstWhere((f) => f['campaignRef'] == campaignRef);
    final alloc = await post(admin, '/funds/${fund['fundId']}/allocations', {'amount': '5000000'});
    expect(alloc.statusCode, 201);
    final reg = await post(employee, '/physical-assets/register', {
      'fundId': fund['fundId'],
      'assetType': 'BLANKET',
      'quantity': '10',
      'unitOfMeasure': 'UNITS',
      'custodianRef': 'bodega-1',
      'currentLocation': 'bodega-1',
      'allocationId': alloc.data!['allocationId'],
    });
    expect(reg.statusCode, 201, reason: 'registrar activo');
    assetRef = reg.data!['assetRef'] as String;
  });

  test('9. operador: ver el activo y DESPACHAR por el Outbox (SyncEngine + AssetOperations)', () async {
    final assets = PhysicalAssetApi(employee.api);
    expect((await assets.get(assetRef)).lifecycleStatus, 'REGISTERED');
    final engine = SyncEngine(store: SecureOutboxStore(InMemorySecureKeyValueStore()), apiClient: employee.api);
    final ops = AssetOperations(engine: engine, api: assets);
    final cmd = AssetCommand.build(AssetAction.dispatch, assetRef, {'carrierRef': 'transportista-1'})!;
    final (_, outcome) = await ops.submit(cmd, accountId: employee.session.principal!.accountId);
    expect(outcome, CommandOutcome.acknowledged);
    expect((await assets.get(assetRef)).lifecycleStatus, 'DISPATCHED');
    expect(await engine.entriesFor(employee.session.principal!.accountId), isEmpty);
  });

  test('10. AMBIGUOUS real: el backend aplicó RECIBIR pero el cliente no lo supo → Verificar estado → confirmada; '
      'el reintento con el mismo Command-Id es idempotente', () async {
    final account = employee.session.principal!.accountId;
    final store = SecureOutboxStore(InMemorySecureKeyValueStore());
    final engine = SyncEngine(store: store, apiClient: employee.api);
    final assets = PhysicalAssetApi(employee.api);
    final cmd = AssetCommand.build(AssetAction.receive, assetRef, {
      'facilityLocation': 'centro-1',
      'receiverRef': 'r-1',
    })!;
    final id = ids.next();
    final item = OutboxItem(
      commandId: id,
      accountId: account,
      kind: cmd.action.wire,
      resourceRef: assetRef,
      path: cmd.path,
      payload: cmd.body,
      status: OutboxStatus.ambiguous, // como tras un timeout o tras T-2
      createdAt: DateTime.now().toUtc(),
    );
    await store.saveItem(item);
    // El comando llegó y se aplicó (respuesta perdida): se simula enviándolo por fuera con el mismo Command-Id.
    final r = await employee.api.post(
      cmd.path,
      body: cmd.body,
      headers: {'Command-Id': id},
      credentialMode: CredentialMode.jwt,
    );
    expect(r.statusCode, 200);

    // Reintento manual con el MISMO Command-Id: el backend responde lo mismo, sin un segundo evento.
    expect(await engine.send(id, account), CommandOutcome.acknowledged);
    expect((await assets.get(assetRef)).lifecycleStatus, 'RECEIVED');

    // Y "Verificar estado" sobre otra entrada AMBIGUOUS de un comando ya aplicado → confirmada sin reenviar.
    await store.saveItem(item.copyWith(status: OutboxStatus.ambiguous));
    final ops = AssetOperations(engine: engine, api: assets);
    expect(await ops.verify(item, accountId: account), isTrue);
  });

  test('11. ENTREGAR → DELIVERED; otra acción sobre un activo entregado → FAILED (409), nunca AMBIGUOUS', () async {
    final account = employee.session.principal!.accountId;
    final engine = SyncEngine(store: SecureOutboxStore(InMemorySecureKeyValueStore()), apiClient: employee.api);
    final ops = AssetOperations(engine: engine, api: PhysicalAssetApi(employee.api));
    final deliver = AssetCommand.build(AssetAction.deliver, assetRef, {
      'finalCustodianRef': 'custodio-final',
      'beneficiaryRef': 'beneficiario-1',
      'locationRef': 'centro-1',
      'evidenceRef': 'acta-1',
    })!;
    expect((await ops.submit(deliver, accountId: account)).$2, CommandOutcome.acknowledged);
    expect((await PhysicalAssetApi(employee.api).get(assetRef)).lifecycleStatus, 'DELIVERED');
    final again = AssetCommand.build(AssetAction.dispatch, assetRef, {'carrierRef': 'x'})!;
    final (entry, outcome) = await ops.submit(again, accountId: account);
    expect(outcome, CommandOutcome.failed);
    final stored = (await engine.entriesFor(account)).single;
    expect(stored.commandId, entry.commandId);
    expect(stored.rejectionStatus, 409);
  });

  test('12. el donante no puede leer el activo (403) ni operar: el backend autoriza, no la app', () async {
    final r = await donor.api.get('/physical-assets/$assetRef', credentialMode: CredentialMode.jwt);
    expect(r.statusCode, 403);
  });

  test(
    '13. predicción real: ADMINISTRATOR y REPRESENTATIVE, kind ESTIMATE con la advertencia; EMPLOYEE → 403',
    () async {
      for (final d in [admin, representative]) {
        final p = await PredictionApi(d.api).get(org, campaignRef);
        expect(p.kind, 'ESTIMATE');
        expect(p.warning, contains('datos sintéticos'));
      }
      final r = await employee.api.get(
        '/organizations/$org/campaigns/$campaignRef/prediction',
        credentialMode: CredentialMode.jwt,
      );
      expect(r.statusCode, 403);
    },
  );

  test('14. T-1 real: un JWT inválido → 401 → sesión cerrada y token borrado', () async {
    final d = Device();
    await d.tokens.writeToken('jwt.invalido.firma');
    await d.session.restore();
    expect(d.session.state.status, SessionStatus.loggedOut);
    expect(await d.tokens.readToken(), isNull);
  });
}
