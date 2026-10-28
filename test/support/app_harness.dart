import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_config.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/app/app_services.dart';
import 'package:paxfide_mobile/app/bootstrap.dart';
import 'package:paxfide_mobile/app/navigation_restore_state.dart';
import 'package:paxfide_mobile/app/paxfide_app.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/features/welcome/presentation/welcome_world.dart';

import 'fakes.dart';

const testOrigin = 'https://paxfide.example';

ApiResponse meResponse({List<String> roles = const ['EMPLOYEE'], String? org = 'org-1', String account = 'acc-1'}) =>
    ApiResponse(statusCode: 200, data: {'accountId': account, 'organizationId': ?org, 'roles': roles});

/// Arranca la app completa con un `ApiClient` falso y almacenamiento en memoria.
class AppHarness {
  /// [biometric]: biometría del teléfono simulada; sin ella, el equipo no tiene (como Linux).
  AppHarness({FakeBiometricAuthenticator? biometric})
    : biometric = biometric ?? FakeBiometricAuthenticator(available: false) {
    // El mundo de la bienvenida se mueve sin parar: en las pruebas, solo la cámara al deslizar (pumpAndSettle termina).
    WelcomeWorld.ambientMotion = false;
    services = buildServices(
      config: AppConfig(apiBaseUrl: Uri.parse('http://api.test/api/v1'), publicOrigin: AppConfig.originOf(testOrigin)),
      secureStore: secure,
      apiClientFactory: (tokens, handler) => api..authHandler = handler,
      qrScannerBuilder: (context, onCode) => _FakeScanner(code: nextScan, onCode: onCode),
      biometricAuthenticator: this.biometric,
      linkOpener: links,
    );
    // Inicio lee el resumen de donaciones en segundo plano: por defecto, ninguna (cada prueba puede cambiarla).
    api.routes['GET /account/donations'] = (_) => const ApiResponse(statusCode: 200, data: {'items': <Object>[]});
    api.routeFirst.add('GET /account/donations');
    // Cuenta lee el correo y el nombre; Mis donaciones, el impacto.
    api.routes['GET /account/profile'] = (_) =>
        const ApiResponse(statusCode: 200, data: {'email': 'persona@demo.paxfide.local'});
    api.routeFirst.add('GET /account/profile');
    api.routes['GET /account/impact'] = (_) => const ApiResponse(
      statusCode: 200,
      data: {
        'donationsCount': 0,
        'totals': <Object>[],
        'campaignsSupported': 0,
        'deliveredUnits': <Object>[],
        'truncated': false,
      },
    );
    api.routeFirst.add('GET /account/impact');
    // Inicio también lee el catálogo de convocatorias.
    api.routes['GET /public/campaigns'] = (_) => const ApiResponse(statusCode: 200, data: {'items': <Object>[]});
    api.routeFirst.add('GET /public/campaigns');
    // Lecturas por defecto para los flujos que solo navegan: un activo cualquiera en REGISTERED.
    api.fallback = (call) {
      if (call.method == 'GET' && call.path.endsWith('/physical-assets') && call.path.startsWith('/organizations/')) {
        return const ApiResponse(statusCode: 200, data: {'items': <Object>[]});
      }
      if (call.method == 'GET' && call.path.startsWith('/physical-assets/')) {
        final ref = Uri.decodeComponent(call.path.split('/').last);
        return ApiResponse(
          statusCode: 200,
          data: {
            'assetRef': ref,
            'lifecycleStatus': 'REGISTERED',
            'currentCustodianRef': 'bodega-1',
            'currentLocation': 'bodega-1',
            'quantity': '1',
            'unitOfMeasure': 'u',
          },
        );
      }
      if (call.method == 'GET' && call.path.startsWith('/public/campaigns/')) {
        if (call.path.endsWith('/narrative')) {
          return const ApiResponse(statusCode: 202, data: {'status': 'PENDING'});
        }
        return const ApiResponse(
          statusCode: 200,
          data: {
            'organizationName': 'Org',
            'title': 'Convocatoria',
            'status': 'OPEN',
            'startDate': '2026-10-01T00:00:00Z',
            'endDate': '2026-12-01T00:00:00Z',
            'acceptedDonationTypes': ['MONETARY'],
          },
        );
      }
      return null;
    };
  }

  final secure = InMemorySecureKeyValueStore();
  final FakeBiometricAuthenticator biometric;

  /// Navegador simulado (M-12).
  final links = FakeLinkOpener();

  /// Biometría ya activada en este teléfono.
  void saveDeviceCredential() =>
      secure.values['paxfide.biometric.device'] = '{"credentialId":"cred-1","deviceToken":"tok-1"}';

  /// Lo que "leerá" la cámara falsa en el próximo escaneo.
  String? nextScan;
  final api = FakeApiClient();
  late final AppServices services;

  void saveToken(String token) => secure.values['paxfide.session.jwt'] = token;

  void saveNavigation(String route, [Map<String, String> params = const {}]) =>
      secure.values['paxfide.navigation.restore'] = NavigationRestoreState(
        route: route,
        allowedParams: params,
        schemaVersion: NavigationRestoreState.currentSchemaVersion,
      ).toJson();

  /// Monta la app y arranca (restauración + sesión). [beforeSession] corre con la sesión aún sin resolver.
  /// Sin sesión la app abre la bienvenida (Enmienda 3). Por defecto, [start] toca después «Iniciar sesión», como
  /// haría el usuario, para los flujos que empiezan en Entrar; con [stayOnWelcome] se queda en la bienvenida.
  Future<void> start(WidgetTester tester, {Future<void> Function()? beforeSession, bool stayOnWelcome = false}) async {
    // Pantalla de teléfono (411 × 891, como un Android común), no la de 800 × 600 por defecto de las pruebas. Una
    // prueba puede cambiarla antes de llamar a start.
    if (tester.view.physicalSize == const Size(2400, 1800)) {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
    }
    await services.theme.load();
    await services.textSize.load();
    await tester.pumpWidget(PaxFideApp(services: services));
    await runOutboxRecovery(services);
    await services.router.loadRestorable();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // termina la transición de páginas
    if (beforeSession != null) await beforeSession();
    await services.session.restore();
    await tester.pumpAndSettle();
    if (!stayOnWelcome && location == AppRoutes.welcome) {
      services.router.push(AppRoutes.login);
      await tester.pumpAndSettle();
    }
  }

  String? get location => services.router.currentLocation;

  Future<void> login(WidgetTester tester, {List<String> roles = const ['EMPLOYEE']}) async {
    api.enqueue(const ApiResponse(statusCode: 200, data: {'token': 'jwt-1'}));
    api.enqueue(meResponse(roles: roles));
    await tester.enterText(find.byKey(const Key('login.email')), 'empleado@demo');
    await tester.enterText(find.byKey(const Key('login.password')), 'pw');
    await tester.ensureVisible(find.byKey(const Key('login.submit')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pumpAndSettle();
  }
}

class _FakeScanner extends StatefulWidget {
  const _FakeScanner({required this.code, required this.onCode});
  final String? code;
  final ValueChanged<String> onCode;

  @override
  State<_FakeScanner> createState() => _FakeScannerState();
}

class _FakeScannerState extends State<_FakeScanner> {
  @override
  void initState() {
    super.initState();
    final code = widget.code;
    if (code != null) WidgetsBinding.instance.addPostFrameCallback((_) => widget.onCode(code));
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
}
