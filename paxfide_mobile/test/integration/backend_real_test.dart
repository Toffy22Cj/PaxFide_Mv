// Recorrido contra el backend REAL en local (runbook-demo-local.md del
// backend, paso 4b: perfil `demo-seed` con el escenario completo).
//
// Se salta salvo que exista PAXFIDE_REAL_API (p. ej.
// http://127.0.0.1:8080/api/v1). Necesita además las variables del demo.env
// del backend: TRACEABILITY_DEMO_SEED_PASSWORD y
// TRACEABILITY_DEMO_WEBHOOK_SECRET. Nunca imprime secretos.
//
// Lo que es de la app se ejercita con su propio código (gateways de login y
// /me, SessionController, CampaignApi, DonationFlow, AccountDonationsApi,
// TrackingApi, SyncEngine, AssetOperations, PredictionApi). El pago simulado
// lo dispara la web de demo: aquí se firma el webhook con openssl.
@Tags(['backend-real'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/network/auth_response_handler.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/core/network/http_api_client.dart';
import 'package:paxfide_mobile/core/offline/command_outcome.dart';
import 'package:paxfide_mobile/core/offline/outbox_status.dart';
import 'package:paxfide_mobile/core/offline/sync_engine.dart';
import 'package:paxfide_mobile/core/storage/outbox_store.dart';
import 'package:paxfide_mobile/core/storage/token_store.dart';
import 'package:paxfide_mobile/features/auth/data/auth_api.dart';
import 'package:paxfide_mobile/features/auth/data/http_auth_gateways.dart';
import 'package:paxfide_mobile/features/auth/data/login_gateway.dart';
import 'package:paxfide_mobile/features/auth/data/session_controller.dart';
import 'package:paxfide_mobile/features/auth/domain/session_state.dart';
import 'package:paxfide_mobile/features/campaigns/data/campaign_api.dart';
import 'package:paxfide_mobile/features/donations/data/account_donations_api.dart';
import 'package:paxfide_mobile/features/donations/data/donation_intent_api.dart';
import 'package:paxfide_mobile/features/donations/domain/donation_flow.dart';
import 'package:paxfide_mobile/features/physical_assets/data/physical_asset_api.dart';
import 'package:paxfide_mobile/features/physical_assets/domain/action_resolver.dart';
import 'package:paxfide_mobile/features/physical_assets/domain/asset_action.dart';
import 'package:paxfide_mobile/features/physical_assets/domain/asset_command.dart';
import 'package:paxfide_mobile/features/physical_assets/domain/asset_operations.dart';
import 'package:paxfide_mobile/features/physical_assets/domain/lifecycle_status.dart';
import 'package:paxfide_mobile/features/prediction/data/prediction_api.dart';
import 'package:paxfide_mobile/features/tracking/data/tracking_api.dart';

import '../support/fakes.dart';

final env = Platform.environment;
final base = env['PAXFIDE_REAL_API'];
String get password => env['TRACEABILITY_DEMO_SEED_PASSWORD']!;

/// Una "instalación" de la app: su TokenStore, su ApiClient real y su sesión.
class Device {
  Device() {
    tokens = SecureTokenStore(InMemorySecureKeyValueStore());
    late SessionController s;
    api = HttpApiClient(
      baseUrl: Uri.parse(base!),
      tokenStore: tokens,
      authResponseHandler: AuthResponseHandler(tokenStore: tokens, onSessionLoggedOut: () => s.markLoggedOutByUnauthorized()),
    );
    auth = AuthApi(api);
    session = s = SessionController(tokenStore: tokens, meGateway: HttpMeGateway(auth));
  }
  late final TokenStore tokens;
  late final HttpApiClient api;
  late final AuthApi auth;
  late final SessionController session;

  Future<void> login(String email) async {
    await session.restore();
    final r = await HttpLoginGateway(auth).login(email: email, password: password);
    expect(r, isA<LoginSucceeded>(), reason: 'login $email');
    await session.establish((r as LoginSucceeded).token);
  }
}

/// HMAC-SHA256 en hexadecimal con el openssl del sistema (solo en este test).
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

  final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
  late String publicCode;
  late String trackingCode;

  test('1. login rechazado: credenciales inválidas → LoginRejected, sin sesión', () async {
    final d = Device();
    await d.session.restore();
    final r = await HttpLoginGateway(d.auth).login(email: 'nadie-$stamp@demo.paxfide.local', password: 'x' * 12);
    expect(r, isA<LoginRejected>());
    expect(d.session.value.status, SessionStatus.loggedOut);
  });

  test('2. roles desde /me: empleado, administrador y representante', () async {
    final employee = Device();
    await employee.login('empleado1@demo.paxfide.local');
    final p = employee.session.value.principal!;
    expect(p.isFieldOperator, isTrue);
    expect(p.isDonor, isFalse);
    expect(p.canSeePrediction, isFalse);

    final admin = Device();
    await admin.login('administrador@demo.paxfide.local');
    expect(admin.session.value.principal!.canSeePrediction, isTrue);

    final rep = Device();
    await rep.login('representante@demo.paxfide.local');
    expect(rep.session.value.principal!.canSeePrediction, isTrue);
    expect(rep.session.value.principal!.isFieldOperator, isFalse);
  });

  test('3. convocatorias públicas: listado, detalle y narrativa', () async {
    final api = CampaignApi(Device().api);
    final page = await api.list();
    final open = page.items.firstWhere((c) => c.status == 'OPEN');
    publicCode = open.publicCode;
    final c = await api.get(publicCode);
    expect(c.title, open.title);
    final n = await api.narrative(publicCode);
    expect(['AVAILABLE', 'PENDING', 'UNAVAILABLE'], contains(n.status));
  });

  test('4. registro, donación con cuenta, pago simulado, código de seguimiento e historial', () async {
    final donor = Device();
    final email = 'movil-$stamp@demo.paxfide.local';
    await donor.auth.register(email, password);
    await donor.login(email);
    expect(donor.session.value.principal!.isDonor, isTrue);

    final flow = DonationFlow(DonationIntentApi(donor.api));
    final attempt = flow.start(publicCode, '5000000', 'COP');
    final (outcome, status) = await flow.create(attempt, withAccount: true);
    expect(outcome, CommandOutcome.acknowledged, reason: 'HTTP $status');
    expect(attempt.intent!.statusToken, isNotNull);

    final session = attempt.intent!.paymentRedirectUrl!.split('/').last;
    final event = {
      'type': 'payment.confirmed',
      'paymentSessionId': session,
      'providerEventId': 'evt-$stamp',
      'amount': '5000000',
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
    for (var i = 0; i < 30 && s?.trackingCode == null; i++) {
      s = await flow.refresh(attempt);
      if (s.trackingCode == null) await Future<void>.delayed(const Duration(seconds: 1));
    }
    expect(s!.status, 'CONFIRMED');
    expect(s.trackingCode, isNotNull);
    trackingCode = s.trackingCode!;

    final mine = await AccountDonationsApi(donor.api).list();
    expect(mine.where((d) => d.amount == '5000000' && d.currency == 'COP'), isNotEmpty);
  });

  test('5. seguimiento con el código en Authorization: resumen, relato e integridad', () async {
    final api = TrackingApi(Device().api);
    final s = await api.summary(trackingCode);
    expect(s.financial.originalAmount, 5000000);
    final n = await api.narrative(trackingCode);
    expect(['AVAILABLE', 'PENDING'], contains(n.status));
    final i = await api.integrity(trackingCode);
    expect(i.unanchoredEvents + i.batches.length, greaterThan(0));
    await expectLater(api.summary('codigo-invalido'), throwsA(isA<InvalidTrackingCodeException>()));
  });

  test('6. operador: activo en tránsito → recibir → entregar por el Outbox', () async {
    final employee = Device();
    await employee.login('empleado1@demo.paxfide.local');
    final principal = employee.session.value.principal!;
    final assets = PhysicalAssetApi(employee.api);
    final list = await assets.organizationAssets(principal.organizationId!);
    final inTransit = list.firstWhere((a) => a.lifecycleStatus == 'DISPATCHED');

    final store = SecureOutboxStore(InMemorySecureKeyValueStore());
    final engine = SyncEngine(store: store, apiClient: employee.api);
    final ops = AssetOperations(engine: engine, api: assets);

    var action = const ActionResolver().resolve(LifecycleStatus.fromApi(inTransit.lifecycleStatus));
    expect(action, AssetAction.receive);
    final receive = AssetCommand.build(action, inTransit.assetRef, {
      'facilityLocation': 'bodega-movil-$stamp',
      'receiverRef': 'operador-movil',
    })!;
    final (_, r1) = await ops.submit(receive, accountId: principal.accountId);
    expect(r1, CommandOutcome.acknowledged);
    expect((await assets.get(inTransit.assetRef)).lifecycleStatus, 'RECEIVED');

    action = const ActionResolver().resolve(LifecycleStatus.received);
    final deliver = AssetCommand.build(action, inTransit.assetRef, {
      'finalCustodianRef': 'comedor-movil',
      'beneficiaryRef': 'beneficiario-movil',
      'locationRef': 'comedor-movil',
      'evidenceRef': 'acta-movil-$stamp',
    })!;
    final (_, r2) = await ops.submit(deliver, accountId: principal.accountId);
    expect(r2, CommandOutcome.acknowledged);
    expect((await assets.get(inTransit.assetRef)).lifecycleStatus, 'DELIVERED');
    expect(await engine.entriesFor(principal.accountId), isEmpty);

    // Un comando ya no permitido es un rechazo inequívoco: FAILED, nunca AMBIGUOUS.
    final again = AssetCommand.build(AssetAction.deliver, inTransit.assetRef, {
      'finalCustodianRef': 'x',
      'beneficiaryRef': 'x',
      'locationRef': 'x',
      'evidenceRef': 'x',
    })!;
    final (item, r3) = await ops.submit(again, accountId: principal.accountId);
    expect(r3, CommandOutcome.failed);
    final entries = await engine.entriesFor(principal.accountId);
    expect(entries.single.status, OutboxStatus.failed);
    await engine.discard(item.commandId, principal.accountId);
  });

  test('7. predicción: el administrador lista convocatorias y consulta la estimación', () async {
    final admin = Device();
    await admin.login('administrador@demo.paxfide.local');
    final p = admin.session.value.principal!;
    final api = PredictionApi(admin.api);
    final choices = await api.organizationCampaigns(p.organizationId!);
    final open = choices.firstWhere((c) => c.status == 'OPEN');
    final prediction = await api.get(p.organizationId!, open.campaignRef);
    expect(prediction.kind, 'ESTIMATE');
    final history = await api.history(p.organizationId!, open.campaignRef);
    expect(history.cuts.length + (history.available ? 0 : 1), greaterThan(0));
  });

  test('8. T-1: un JWT inválido en /me cierra la sesión y limpia el token', () async {
    final d = Device();
    await d.tokens.writeToken('jwt-invalido');
    await d.session.restore();
    expect(d.session.value.status, SessionStatus.loggedOut);
    expect(await d.tokens.readToken(), isNull);
  });
}
