import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/features/welcome/presentation/welcome_screen.dart';
import 'package:paxfide_mobile/shared/theme/text_size_controller.dart';
import 'package:paxfide_mobile/shared/theme/theme_controller.dart';

import '../../support/app_harness.dart';

Map<String, Object> campaign(String code, {String status = 'OPEN'}) => {
  'publicCode': code,
  'title': 'Convocatoria $code',
  'organizationName': 'Fundación Demo',
  'status': status,
  'startDate': '2026-10-01',
  'endDate': '2099-12-31',
  'currency': 'COP',
  'targetAmount': '100000',
  'clearedAmount': '62000',
};

ApiResponse list(List<Map<String, Object>> items) => ApiResponse(statusCode: 200, data: {'items': items});

/// `/welcome`: la primera pantalla sin sesión (Enmienda 3).
Future<AppHarness> openWelcome(WidgetTester tester, {Object Function()? campaigns}) async {
  final h = AppHarness();
  h.api.routes['GET /public/campaigns'] = (_) => campaigns?.call() ?? list([]);
  await h.start(tester, stayOnWelcome: true);
  expect(h.location, AppRoutes.welcome);
  return h;
}

Future<void> scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    300,
    scrollable: find.descendant(of: find.byKey(const Key('welcome.list')), matching: find.byType(Scrollable)),
  );
  await tester.pumpAndSettle();
  // Centrado, para que no quede bajo la barra flotante de arriba ni bajo «Ingresar».
  await Scrollable.ensureVisible(tester.element(f), alignment: 0.5);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('qué es PaxFide y el recorrido en cinco pasos, sin datos de ejemplo ni campo de código', (tester) async {
    await openWelcome(tester);
    expect(find.textContaining('Tu donación, de principio a fin', findRichText: true), findsWidgets);
    for (var i = 1; i <= 5; i++) {
      await scrollTo(tester, find.byKey(Key('welcome.step.$i')));
      expect(find.textContaining('0$i / 05'), findsOneWidget);
    }
    for (final banned in ['EJEMPLO', 'Lorica', 'Lote ilustrativo', '120 kits', 'Merkle', 'SHA-256', 'PhysicalAsset']) {
      expect(
        find.descendant(of: find.byType(WelcomeScreen), matching: find.textContaining(banned)),
        findsNothing,
        reason: banned,
      );
    }
    expect(
      find.descendant(of: find.byType(WelcomeScreen), matching: find.byType(TextField)),
      findsNothing,
      reason: 'el código solo se escribe en /tracking',
    );
  });

  testWidgets('acciones: Iniciar sesión fijo, Tengo un código y Seguir mi donación', (tester) async {
    var h = await openWelcome(tester);
    expect(find.byKey(const Key('welcome.login')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('welcome.login'))).height, greaterThanOrEqualTo(52));
    await tester.tap(find.byKey(const Key('welcome.login')));
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.login);

    h = await openWelcome(tester);
    await scrollTo(tester, find.byKey(const Key('welcome.tracking')));
    await tester.tap(find.byKey(const Key('welcome.tracking')));
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.tracking);

    h = await openWelcome(tester);
    await scrollTo(tester, find.byKey(const Key('welcome.tracking.card')));
    await tester.tap(find.byKey(const Key('welcome.tracking.card')));
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.tracking);
  });

  testWidgets('¿Eres una organización? lleva a crear la cuenta', (tester) async {
    final h = await openWelcome(tester);
    await scrollTo(tester, find.byKey(const Key('welcome.organization')));
    expect(find.text('¿Eres una organización?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('welcome.organization')));
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.register);
  });

  testWidgets('Donar baja hasta las convocatorias', (tester) async {
    await openWelcome(tester, campaigns: () => list([campaign('PUB1')]));
    final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    double top() => tester.getTopLeft(find.byKey(const Key('welcome.campaigns.all'), skipOffstage: false)).dy;
    expect(top(), greaterThan(screen), reason: 'al abrir, el catálogo está más abajo');
    await scrollTo(tester, find.byKey(const Key('welcome.donate')));
    await tester.tap(find.byKey(const Key('welcome.donate')));
    await tester.pumpAndSettle();
    expect(top(), lessThan(screen));
  });

  testWidgets('la vista previa solo muestra convocatorias abiertas', (tester) async {
    await openWelcome(tester, campaigns: () => list([campaign('PUB1'), campaign('PUB9', status: 'CLOSED')]));
    await scrollTo(tester, find.byKey(const Key('welcome.campaign.PUB1')));
    expect(find.byKey(const Key('welcome.campaign.PUB9')), findsNothing);
  });

  testWidgets('catálogo real: como mucho tres tarjetas y «Ver detalles» abre /c/:publicCode', (tester) async {
    final h = await openWelcome(
      tester,
      campaigns: () => list([campaign('PUB1'), campaign('PUB2'), campaign('PUB3'), campaign('PUB4')]),
    );
    await scrollTo(tester, find.byKey(const Key('welcome.campaign.PUB3')));
    expect(find.byKey(const Key('welcome.campaign.PUB4'), skipOffstage: false), findsNothing);
    final call = h.api.calls.firstWhere((c) => c.path == '/public/campaigns');
    expect(call.headers.containsKey('Authorization'), isFalse, reason: 'sin sesión');
    await scrollTo(tester, find.byKey(const Key('welcome.campaign.PUB1.details')));
    await tester.tap(find.byKey(const Key('welcome.campaign.PUB1.details')));
    await tester.pumpAndSettle();
    expect(h.location, '/c/PUB1');
  });

  testWidgets('catálogo: cargando (esqueleto) y vacío', (tester) async {
    final pending = Completer<Object>();
    await openWelcome(tester, campaigns: () => pending.future);
    await scrollTo(tester, find.byKey(const Key('welcome.campaigns.loading')));
    expect(find.byKey(const Key('welcome.campaigns.loading')), findsOneWidget);
    pending.complete(list([]));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('welcome.campaigns.empty')));
    expect(find.text('No hay convocatorias abiertas en este momento.'), findsOneWidget);
  });

  testWidgets('catálogo con error: «Reintentar» vuelve a pedirlo', (tester) async {
    var fail = true;
    await openWelcome(tester, campaigns: () => fail ? const NetworkTimeoutException() : list([campaign('PUB1')]));
    await scrollTo(tester, find.byKey(const Key('welcome.campaigns.retry')));
    fail = false;
    await tester.tap(find.byKey(const Key('welcome.campaigns.retry')));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('welcome.campaign.PUB1')));
    expect(find.byKey(const Key('welcome.campaign.PUB1')), findsOneWidget);
  });

  testWidgets('modo oscuro con el texto «Muy grande»: nada se corta', (tester) async {
    final h = AppHarness();
    h.secure.values[ThemeController.storageKey] = 'dark';
    h.secure.values[TextSizeController.storageKey] = TextSize.extraLarge.name;
    h.api.routes['GET /public/campaigns'] = (_) => list([campaign('PUB1'), campaign('PUB2')]);
    await h.start(tester, stayOnWelcome: true);
    for (final k in ['welcome.step.3', 'welcome.step.5', 'welcome.tracking.card', 'welcome.campaign.PUB2']) {
      await scrollTo(tester, find.byKey(Key(k)));
      expect(tester.takeException(), isNull, reason: k);
    }
  });

  testWidgets('todas las acciones llevan Key con el prefijo welcome. y miden al menos 40 de alto', (tester) async {
    await openWelcome(tester, campaigns: () => list([campaign('PUB1')]));
    for (final k in ['welcome.scan', 'welcome.tracking', 'welcome.donate', 'welcome.login']) {
      expect(tester.getSize(find.byKey(Key(k))).height, greaterThanOrEqualTo(40), reason: k);
    }
  });
}
