import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_config.dart';
import 'package:paxfide_mobile/app/app_services.dart';
import 'package:paxfide_mobile/app/bootstrap.dart';
import 'package:paxfide_mobile/app/navigation_restore_state.dart';
import 'package:paxfide_mobile/app/paxfide_app.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';

import 'fakes.dart';

const testOrigin = 'https://paxfide.example';

ApiResponse meResponse({List<String> roles = const ['EMPLOYEE'], String? org = 'org-1', String account = 'acc-1'}) =>
    ApiResponse(statusCode: 200, data: {'accountId': account, 'organizationId': ?org, 'roles': roles});

/// Arranca la app completa con un `ApiClient` falso y almacenamiento en memoria.
class AppHarness {
  AppHarness() {
    services = buildServices(
      config: AppConfig(apiBaseUrl: Uri.parse('http://api.test/api/v1'), publicOrigin: AppConfig.originOf(testOrigin)),
      secureStore: secure,
      apiClientFactory: (tokens, handler) => api..authHandler = handler,
      qrScannerBuilder: (context, onCode) => _FakeScanner(code: nextScan, onCode: onCode),
    );
    // Lecturas por defecto para los flujos que solo navegan: un activo cualquiera en REGISTERED.
    api.fallback = (call) {
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
  Future<void> start(WidgetTester tester, {Future<void> Function()? beforeSession}) async {
    await tester.pumpWidget(PaxFideApp(services: services));
    await runOutboxRecovery(services);
    await services.router.loadRestorable();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // termina la transición de páginas
    if (beforeSession != null) await beforeSession();
    await services.session.restore();
    await tester.pumpAndSettle();
  }

  String? get location => services.router.currentLocation;

  Future<void> login(WidgetTester tester, {List<String> roles = const ['EMPLOYEE']}) async {
    api.enqueue(const ApiResponse(statusCode: 200, data: {'token': 'jwt-1'}));
    api.enqueue(meResponse(roles: roles));
    await tester.enterText(find.byKey(const Key('login.email')), 'empleado@demo');
    await tester.enterText(find.byKey(const Key('login.password')), 'pw');
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
