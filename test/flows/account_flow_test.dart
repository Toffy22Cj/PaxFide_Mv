import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/offline/outbox_item.dart';
import 'package:paxfide_mobile/core/offline/outbox_status.dart';
import 'package:paxfide_mobile/core/storage/outbox_store.dart';

import '../support/app_harness.dart';

/// E-12 / M-26: pestaña Cuenta.
/// La lista de Cuenta (para desplazarla hasta lo que queda debajo del pliegue).
final _accountList = find.ancestor(of: find.byKey(const Key('account.identity')), matching: find.byType(Scrollable));

void main() {
  Future<AppHarness> start(
    WidgetTester tester, {
    List<String> roles = const ['EMPLOYEE'],
    String? org = 'org-1',
  }) async {
    final h = AppHarness();
    h.saveToken('jwt');
    await h.start(
      tester,
      beforeSession: () async => h.api.enqueue(meResponse(roles: roles, org: org)),
    );
    return h;
  }

  testWidgets('el empleado y el donante tienen la pestaña Cuenta con su rol', (tester) async {
    var h = await start(tester);
    expect(find.byKey(const Key('nav.Cuenta')), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav.Cuenta')));
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.account);
    expect(find.text('Empleado'), findsOneWidget);
    expect(find.text('Perteneces a una organización'), findsOneWidget);
    expect(find.byKey(const Key('account.invitation')), findsNothing);

    h = await start(tester, roles: const [], org: null);
    await tester.tap(find.byKey(const Key('nav.Cuenta')));
    await tester.pumpAndSettle();
    expect(find.text('Donante'), findsOneWidget);
    expect(find.byKey(const Key('account.invitation')), findsOneWidget);
  });

  testWidgets('cerrar sesión pide confirmación y avisa de las operaciones guardadas, sin borrarlas', (tester) async {
    final h = AppHarness();
    await SecureOutboxStore(h.secure).saveItem(
      OutboxItem(
        commandId: 'cmd-1',
        accountId: 'acc-1',
        kind: 'DISPATCH',
        resourceRef: 'A-1',
        path: '/physical-assets/A-1/dispatch',
        payload: const {'carrierRef': 'c'},
        status: OutboxStatus.pending,
        createdAt: DateTime.utc(2026, 10, 21),
      ),
    );
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse()));
    h.services.router.go(AppRoutes.account);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byKey(const Key('account.logout')), 200, scrollable: _accountList);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account.logout')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tienes 1 operación guardada'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.account);

    await tester.tap(find.byKey(const Key('account.logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account.logout.yes')));
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.login);
    expect(await SecureOutboxStore(h.secure).getAllItems(), hasLength(1));
  });

  testWidgets('aceptar una invitación: token en el cuerpo, recarga el perfil; 403 da un mensaje claro', (tester) async {
    final h = await start(tester, roles: const [], org: null);
    h.services.router.go(AppRoutes.account);
    await tester.pumpAndSettle();

    h.api.routes['POST /invitations/accept'] = (_) => const ApiResponse(statusCode: 403);
    await tester.enterText(find.byKey(const Key('account.invitation.token')), 'TOK-MALO');
    await tester.tap(find.byKey(const Key('account.invitation.accept')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account.invitation.error')), findsOneWidget);

    h.api.routes['POST /invitations/accept'] = (_) => const ApiResponse(
      statusCode: 200,
      data: {
        'organizationId': 'org-9',
        'roles': ['EMPLOYEE'],
      },
    );
    h.api.routes['GET /me'] = (_) => meResponse(org: 'org-9');
    await tester.enterText(find.byKey(const Key('account.invitation.token')), 'TOK-BUENO');
    await tester.tap(find.byKey(const Key('account.invitation.accept')));
    await tester.pumpAndSettle();
    final call = h.api.calls.lastWhere((c) => c.path == '/invitations/accept');
    expect(call.body, {'token': 'TOK-BUENO'});
    expect(call.path, isNot(contains('TOK')));
    expect(find.text('Empleado'), findsOneWidget);
    expect(h.secure.values.values.join(), isNot(contains('TOK-BUENO')));
  });

  testWidgets('M-26: Cuenta muestra el correo y permite editar el nombre', (tester) async {
    final h = await start(tester);
    h.api.routes['GET /account/profile'] = (_) =>
        const ApiResponse(statusCode: 200, data: {'email': 'empleado@demo.paxfide.local'});
    h.services.router.go(AppRoutes.account);
    await tester.pumpAndSettle();
    expect(find.text('empleado@demo.paxfide.local'), findsOneWidget);
    expect(find.text('Sin nombre'), findsOneWidget);

    h.api.routes['PUT /account/profile'] = (call) => ApiResponse(
      statusCode: 200,
      data: {'email': 'empleado@demo.paxfide.local', ...?call.body?.map((k, v) => MapEntry(k, v))},
    );
    await tester.tap(find.byKey(const Key('account.name.edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('account.name.given')), ' Ana ');
    await tester.enterText(find.byKey(const Key('account.name.family')), 'Pérez');
    await tester.tap(find.byKey(const Key('account.name.save')));
    await tester.pumpAndSettle();
    expect(h.api.calls.lastWhere((c) => c.method == 'PUT').body, {'givenName': 'Ana', 'familyName': 'Pérez'});
    expect(find.text('Ana Pérez'), findsOneWidget);
  });

  testWidgets('M-27: cambiar la contraseña valida en el teléfono y sustituye el token', (tester) async {
    final h = await start(tester);
    h.services.router.go(AppRoutes.account);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('account.password')), 200, scrollable: _accountList);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account.password')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('account.password.current')), 'actual-12345');
    await tester.enterText(find.byKey(const Key('account.password.new')), 'corta');
    await tester.enterText(find.byKey(const Key('account.password.repeat')), 'corta');
    await tester.tap(find.byKey(const Key('account.password.save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('al menos 12 caracteres'), findsWidgets);
    expect(h.api.calls.where((c) => c.path == '/account/password'), isEmpty);

    await tester.enterText(find.byKey(const Key('account.password.new')), 'nueva-1234567');
    await tester.enterText(find.byKey(const Key('account.password.repeat')), 'otra-12345678');
    await tester.tap(find.byKey(const Key('account.password.save')));
    await tester.pumpAndSettle();
    expect(find.text('Las dos contraseñas nuevas no coinciden.'), findsOneWidget);

    h.api.routes['POST /account/password'] = (_) =>
        const ApiResponse(statusCode: 400, data: {'title': 'CurrentPasswordIncorrect', 'status': 400});
    await tester.enterText(find.byKey(const Key('account.password.repeat')), 'nueva-1234567');
    await tester.tap(find.byKey(const Key('account.password.save')));
    await tester.pumpAndSettle();
    expect(find.text('La contraseña actual no es correcta.'), findsOneWidget);
    expect(h.location, AppRoutes.account, reason: 'un 400 nunca cierra la sesión (T-1)');

    h.api.routes['POST /account/password'] = (_) => const ApiResponse(statusCode: 200, data: {'token': 'jwt-nuevo'});
    await tester.tap(find.byKey(const Key('account.password.save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account.password.done')), findsOneWidget);
    expect(await h.services.session.tokenStore.readToken(), 'jwt-nuevo');
    expect(h.location, AppRoutes.account);
  });

  testWidgets('M-30: desactivar pide la contraseña, explica los bloqueos y al final cierra la sesión', (tester) async {
    final h = await start(tester);
    h.services.router.go(AppRoutes.account);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('account.deactivate')), 200, scrollable: _accountList);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account.deactivate')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('account.deactivate.confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Escribe tu contraseña para confirmar.'), findsOneWidget);
    expect(h.api.calls.where((c) => c.path == '/account/deactivate'), isEmpty);

    h.api.routes['POST /account/deactivate'] = (_) =>
        const ApiResponse(statusCode: 409, data: {'title': 'ActiveCampaignResponsible', 'status': 409});
    await tester.enterText(find.byKey(const Key('account.deactivate.password')), 'actual-12345');
    await tester.tap(find.byKey(const Key('account.deactivate.confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('responsable de una convocatoria abierta'), findsOneWidget);
    expect(h.location, AppRoutes.account);

    h.api.routes['POST /account/deactivate'] = (_) => const ApiResponse(statusCode: 204);
    await tester.tap(find.byKey(const Key('account.deactivate.confirm')));
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.login);
    expect(await h.services.session.tokenStore.readToken(), isNull);
    expect(h.api.calls.lastWhere((c) => c.path == '/account/deactivate').body, {'currentPassword': 'actual-12345'});
  });
}
