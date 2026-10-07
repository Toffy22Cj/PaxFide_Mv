import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/offline/outbox_item.dart';
import 'package:paxfide_mobile/core/offline/outbox_status.dart';
import 'package:paxfide_mobile/core/storage/outbox_store.dart';

import '../support/app_harness.dart';

OutboxItem entry(String id, OutboxStatus status, {String account = 'acc-1', String asset = 'A-1'}) => OutboxItem(
  commandId: id,
  accountId: account,
  kind: 'DISPATCH',
  resourceRef: asset,
  path: '/physical-assets/$asset/dispatch',
  payload: const {'carrierRef': 'c'},
  status: status,
  createdAt: DateTime.utc(2026, 10, 7),
);

/// Flujos del Outbox (front-fase1.md §14 nivel 3; ADR-043 D6 con H2).
void main() {
  Future<AppHarness> start(WidgetTester tester, {List<OutboxItem> stored = const [], String account = 'acc-1'}) async {
    final h = AppHarness();
    for (final i in stored) {
      await SecureOutboxStore(h.secure).saveItem(i);
    }
    h.saveToken('jwt');
    await tester.pumpWidget(const SizedBox());
    // El arnés arranca igual que main(): T-2 antes de cualquier otra cosa.
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse(account: account)));
    return h;
  }

  int posts(AppHarness h) =>
      h.api.calls.where((c) => c.method == 'POST' && c.path.startsWith('/physical-assets/')).length;

  testWidgets('la app muere con IN_FLIGHT → al arrancar AMBIGUOUS (T-2), visible en pendientes, sin reenviar', (
    tester,
  ) async {
    final h = await start(tester, stored: [entry('cmd-1', OutboxStatus.inFlight)]);
    h.services.router.go(AppRoutes.operator);
    h.services.router.push(AppRoutes.operatorPending);
    await tester.pumpAndSettle();
    expect(find.textContaining('No pudimos confirmar la operación'), findsOneWidget);
    expect(find.byKey(const Key('outbox.verify.cmd-1')), findsOneWidget);
    expect(posts(h), 0, reason: 'IN_FLIGHT nunca vuelve a PENDING ni se reenvía solo');
    final stored = await SecureOutboxStore(h.secure).getAllItems();
    expect(stored.single.status, OutboxStatus.ambiguous);
  });

  testWidgets('pendientes: AMBIGUOUS → Verificar estado (GET) → confirmada y retirada', (tester) async {
    final h = await start(tester, stored: [entry('cmd-1', OutboxStatus.ambiguous)]);
    h.api.routes['GET /physical-assets/A-1'] = (_) => const ApiResponse(
      statusCode: 200,
      data: {
        'assetRef': 'A-1',
        'lifecycleStatus': 'DISPATCHED',
        'currentCustodianRef': 'x',
        'currentLocation': 'y',
        'quantity': '1',
        'unitOfMeasure': 'u',
      },
    );
    h.services.router.go(AppRoutes.operator);
    h.services.router.push(AppRoutes.operatorPending);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('outbox.verify.cmd-1')));
    await tester.pumpAndSettle();
    expect(find.text('No hay operaciones pendientes de tu cuenta.'), findsOneWidget);
    expect(posts(h), 0);
  });

  testWidgets('pendientes: FAILED → Descartar pide confirmación; cancelar no borra', (tester) async {
    final h = await start(tester, stored: [entry('cmd-1', OutboxStatus.failed)]);
    h.services.router.go(AppRoutes.operator);
    h.services.router.push(AppRoutes.operatorPending);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('outbox.retry.cmd-1')), findsNothing, reason: 'FAILED no se reintenta');
    await tester.tap(find.byKey(const Key('outbox.discard.cmd-1')));
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar la operación?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect((await SecureOutboxStore(h.secure).getAllItems()).length, 1);
    await tester.tap(find.byKey(const Key('outbox.discard.cmd-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
    await tester.pumpAndSettle();
    expect(await SecureOutboxStore(h.secure).getAllItems(), isEmpty);
    expect(posts(h), 0, reason: 'descartar no envía nada');
  });

  testWidgets('H2: otra cuenta no ve ni envía las entradas; tras volver la cuenta dueña, reaparecen', (tester) async {
    final h = await start(
      tester,
      stored: [entry('cmd-A', OutboxStatus.pending, account: 'acc-1')],
      account: 'acc-2',
    );
    h.services.router.go(AppRoutes.operator);
    h.services.router.push(AppRoutes.operatorPending);
    await tester.pumpAndSettle();
    expect(find.text('No hay operaciones pendientes de tu cuenta.'), findsOneWidget);
    expect(find.byKey(const Key('outbox.entry.cmd-A')), findsNothing);

    // El activo de la entrada ajena tampoco la muestra.
    h.services.router.push('/assets/A-1');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('outbox.entry.cmd-A')), findsNothing);
    expect(posts(h), 0);

    // Logout: las entradas siguen guardadas.
    await h.services.session.logout();
    await tester.pumpAndSettle();
    expect((await SecureOutboxStore(h.secure).getAllItems()).single.commandId, 'cmd-A');

    // Entra la cuenta dueña: reaparece.
    h.api.enqueue(const ApiResponse(statusCode: 200, data: {'token': 'jwt-a'}));
    h.api.enqueue(meResponse(account: 'acc-1'));
    await tester.enterText(find.byKey(const Key('login.email')), 'a@demo');
    await tester.enterText(find.byKey(const Key('login.password')), 'pw');
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pumpAndSettle();
    h.services.router.go(AppRoutes.operator);
    h.services.router.push(AppRoutes.operatorPending);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('outbox.entry.cmd-A')), findsOneWidget);
    expect(posts(h), 0, reason: 'reaparecer no envía nada');
  });

  testWidgets('T-1 con entradas AMBIGUOUS: el logout no las borra', (tester) async {
    final h = await start(tester, stored: [entry('cmd-1', OutboxStatus.ambiguous)]);
    h.api.enqueue(const ApiResponse(statusCode: 401));
    try {
      await h.services.authApi.me();
    } catch (_) {}
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.login);
    expect((await SecureOutboxStore(h.secure).getAllItems()).single.status, OutboxStatus.ambiguous);
  });

  testWidgets('sin conexión al enviar: queda PENDING en el dispositivo y "Enviar" lo manda después', (tester) async {
    final h = await start(tester);
    h.services.router.push('/assets/A-1');
    await tester.pumpAndSettle();
    h.api.enqueue(const ConnectionNotEstablishedException());
    await tester.tap(find.byKey(const Key('asset.action')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('form.carrierRef')), 'transportista-1');
    await tester.tap(find.byKey(const Key('form.submit')));
    await tester.pumpAndSettle();
    final stored = (await SecureOutboxStore(h.secure).getAllItems()).single;
    expect(stored.status, OutboxStatus.pending);
    expect(stored.accountId, 'acc-1');
    expect(find.text('Pendiente de enviar\nGuardada en este dispositivo. No se ha enviado.'), findsOneWidget);
    expect(find.byKey(const Key('asset.action')), findsNothing, reason: 'no se apila otra operación');

    h.api.enqueue(const ApiResponse(statusCode: 200, data: {}));
    await tester.tap(find.byKey(Key('outbox.send.${stored.commandId}')));
    await tester.pumpAndSettle();
    expect(await SecureOutboxStore(h.secure).getAllItems(), isEmpty);
    final sent = h.api.calls.where((c) => c.method == 'POST').last;
    expect(sent.headers['Command-Id'], stored.commandId, reason: 'el envío posterior usa el mismo Command-Id');
  });
}
