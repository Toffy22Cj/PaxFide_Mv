import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/offline/outbox_item.dart';
import 'package:paxfide_mobile/core/offline/outbox_status.dart';
import 'package:paxfide_mobile/core/storage/outbox_store.dart';

import '../support/app_harness.dart';

/// E-12 / M-26: pestaña Cuenta.
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
}
