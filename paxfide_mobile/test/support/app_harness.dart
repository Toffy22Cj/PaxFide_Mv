import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_config.dart';
import 'package:paxfide_mobile/app/app_services.dart';
import 'package:paxfide_mobile/app/paxfide_app.dart';
import 'package:paxfide_mobile/features/auth/data/login_gateway.dart';
import 'package:paxfide_mobile/features/auth/data/me_gateway.dart';
import 'package:paxfide_mobile/features/auth/data/session_controller.dart';

import 'fakes.dart';

/// App completa con dobles: `ApiClient` falso, almacenes en memoria y
/// gateways de login y `/me` configurables.
class Harness {
  Harness({
    String? token,
    LoginResult loginResult = const LoginUnavailable(),
    MeResult meResult = const MeSucceeded(donor),
    Uri? publicOrigin,
  })  : api = FakeApiClient(),
        tokenStore = FakeTokenStore(token: token),
        outboxStore = FakeOutboxStore(),
        loginGateway = FakeLoginGateway(loginResult),
        meGateway = FakeMeGateway(meResult) {
    // Respuestas por defecto de las secciones de la home.
    api.routes['GET /public/campaigns'] = (_) => ok({'items': <Object>[]});
    api.routes['GET /account/donations'] = (_) => ok({'items': <Object>[]});
    session = SessionController(tokenStore: tokenStore, meGateway: meGateway);
    services = AppServices(
      config: AppConfig(apiBaseUrl: Uri.parse('http://test/api/v1'), publicOrigin: publicOrigin),
      apiClient: api,
      session: session,
      loginGateway: loginGateway,
      outboxStore: outboxStore,
      qrScannerBuilder: (context, onCode) => const SizedBox.shrink(),
    );
  }

  final FakeApiClient api;
  final FakeTokenStore tokenStore;
  final FakeOutboxStore outboxStore;
  final FakeLoginGateway loginGateway;
  final FakeMeGateway meGateway;
  late final SessionController session;
  late final AppServices services;

  Future<void> pump(
    WidgetTester tester, {
    String initialRoute = '/home',
    bool restore = true,
    Size size = const Size(400, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(PaxFideApp(services: services, initialRoute: initialRoute));
    if (restore) {
      await session.restore();
      await tester.pumpAndSettle();
    } else {
      // La UI de espera anima indefinidamente: no se puede "asentar".
      await tester.pump();
    }
  }
}

Future<void> fillLogin(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('login-email')), 'ana@correo.co');
  await tester.enterText(find.byKey(const Key('login-password')), 'secreta');
  await tester.tap(find.byKey(const Key('login-submit')));
  await tester.pumpAndSettle();
}

/// Ruta visible del navegador raíz.
String? currentRoute(WidgetTester tester) {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  String? current;
  navigator.popUntil((route) {
    current ??= route.settings.name;
    return true;
  });
  return current;
}
