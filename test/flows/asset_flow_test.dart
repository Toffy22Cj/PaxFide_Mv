import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';

import '../support/app_harness.dart';

ApiResponse asset(String status) => ApiResponse(
  statusCode: 200,
  data: {
    'assetRef': 'A-1',
    'lifecycleStatus': status,
    'currentCustodianRef': 'bodega-1',
    'currentLocation': 'bodega-1',
    'quantity': '10',
    'unitOfMeasure': 'kg',
  },
);

void main() {
  late AppHarness h;
  late String status;

  Future<void> openAsset(WidgetTester tester, {List<String> roles = const ['EMPLOYEE']}) async {
    h = AppHarness();
    status = 'REGISTERED';
    h.api.routes['GET /physical-assets/A-1'] = (_) => asset(status);
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse(roles: roles)));
    h.services.router.push('/assets/A-1');
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    // Las listas largas (el formulario de Entregar) no construyen lo que queda debajo del pliegue.
    if (f.evaluate().isEmpty) {
      final list = find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(f, 200, scrollable: list);
    }
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
  }

  Iterable<dynamic> posts() => h.api.calls.where((c) => c.method == 'POST');

  /// Formulario (E-04) → Revisión (E-05) → Resultado (E-06) → "Listo". Devuelve el resultado mostrado.
  Future<String> confirmAndClose(WidgetTester tester) async {
    await tester.pumpAndSettle();
    expect(find.text('Esto queda registrado para siempre.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('review.confirm')));
    await tester.pumpAndSettle();
    final shown = [
      'acknowledged',
      'notSent',
      'ambiguous',
      'failed',
    ].firstWhere((o) => find.byKey(Key('result.$o')).evaluate().isNotEmpty);
    await tap(tester, find.byKey(const Key('result.close')));
    await tester.pumpAndSettle();
    return shown;
  }

  Future<String> fillDispatch(WidgetTester tester) async {
    await tap(tester, find.byKey(const Key('asset.action')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('form.carrierRef')), 'transportista-1');
    await tester.tap(find.byKey(const Key('form.submit')));
    return confirmAndClose(tester);
  }

  testWidgets('muestra el activo y, a un EMPLOYEE, la acción que deriva ActionResolver', (tester) async {
    await openAsset(tester);
    expect(find.text('Registrado'), findsOneWidget);
    expect(find.text('10 kg'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Despachar'), findsOneWidget);
  });

  testWidgets('sin EMPLOYEE en /me no se muestra ninguna acción', (tester) async {
    await openAsset(tester, roles: const ['ADMINISTRATOR']);
    expect(find.text('Registrado'), findsOneWidget);
    expect(find.byKey(const Key('asset.action')), findsNothing);
  });

  testWidgets('DELIVERED → solo lectura', (tester) async {
    h = AppHarness();
    h.api.routes['GET /physical-assets/A-1'] = (_) => asset('DELIVERED');
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse()));
    h.services.router.push('/assets/A-1');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('asset.action')), findsNothing);
    expect(find.text('Este activo ya fue entregado. Solo se puede consultar.'), findsOneWidget);
  });

  testWidgets('403 (también inexistente u otra organización) → estado de pantalla, sin redirect', (tester) async {
    h = AppHarness();
    h.api.routes['GET /physical-assets/A-1'] = (_) => const ApiResponse(statusCode: 403);
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse()));
    h.services.router.push('/assets/A-1');
    await tester.pumpAndSettle();
    expect(h.location, '/assets/A-1');
    expect(find.text('No tienes acceso a este activo.'), findsOneWidget);
  });

  testWidgets('despachar: POST con Command-Id, cuerpo exacto y JWT; 200 → confirmada', (tester) async {
    await openAsset(tester);
    h.api.routes['POST /physical-assets/A-1/dispatch'] = (_) {
      status = 'DISPATCHED';
      return const ApiResponse(statusCode: 200, data: {'assetRef': 'A-1', 'status': 'DISPATCHED'});
    };
    expect(await fillDispatch(tester), 'acknowledged');
    final post = posts().single;
    expect(post.path, '/physical-assets/A-1/dispatch');
    expect(post.body, {'carrierRef': 'transportista-1'});
    expect(post.credentialMode, CredentialMode.jwt);
    expect(post.headers['Command-Id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(find.text('Despachado'), findsOneWidget);
    // ACKNOWLEDGED es terminal: se retira del Outbox.
    expect(await h.services.syncEngine.entriesFor('acc-1'), isEmpty);
    expect(find.widgetWithText(FilledButton, 'Recibir'), findsOneWidget);
  });

  testWidgets('timeout → "no pudimos confirmar"; Verificar estado primero; nunca reintenta solo', (tester) async {
    await openAsset(tester);
    h.api.routes['POST /physical-assets/A-1/dispatch'] = (_) => const NetworkTimeoutException();
    expect(await fillDispatch(tester), 'ambiguous');
    expect(find.textContaining('No pudimos confirmar la operación'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Verificar estado'), findsOneWidget);
    // Mientras está AMBIGUOUS no se ofrece la acción original.
    expect(find.byKey(const Key('asset.action')), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    expect(posts().length, 1, reason: 'AMBIGUOUS nunca se reintenta automáticamente');

    status = 'DISPATCHED';
    await tap(tester, find.widgetWithText(FilledButton, 'Verificar estado'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No pudimos confirmar'), findsNothing);
    expect(find.text('Despachado'), findsOneWidget);
    expect(await h.services.syncEngine.entriesFor('acc-1'), isEmpty);
    expect(posts().length, 1, reason: 'verificar es un GET, no un reenvío');
  });

  testWidgets('verificar con estado distinto → sigue AMBIGUOUS', (tester) async {
    await openAsset(tester);
    h.api.routes['POST /physical-assets/A-1/dispatch'] = (_) => const NetworkTimeoutException();
    await fillDispatch(tester);
    await tester.pumpAndSettle();
    await tap(tester, find.widgetWithText(FilledButton, 'Verificar estado'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No pudimos confirmar'), findsOneWidget);
  });

  testWidgets('AMBIGUOUS: solo "Verificar estado", nunca "Reintentar"', (tester) async {
    await openAsset(tester);
    h.api.routes['POST /physical-assets/A-1/dispatch'] = (_) => const NetworkTimeoutException();
    await fillDispatch(tester);
    expect(find.text('Reintentar'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Verificar estado'), findsOneWidget);
    expect(posts().length, 1);
  });

  testWidgets('el formulario avisa bajo cada campo que no se escriban nombres ni documentos', (tester) async {
    await openAsset(tester);
    await tap(tester, find.byKey(const Key('asset.action')));
    await tester.pumpAndSettle();
    expect(find.textContaining('nunca un nombre ni un número de documento'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('form.carrierRef')), 'transportista-1');
    await tester.tap(find.byKey(const Key('form.submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('review.edit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('form.carrierRef')), findsOneWidget, reason: 'volver a editar');
    expect(posts(), isEmpty, reason: 'nada se envía sin confirmar en la revisión');
  });

  testWidgets('409 → rechazada; "Nueva operación" usa un Command-Id nuevo', (tester) async {
    await openAsset(tester);
    h.api.routes['POST /physical-assets/A-1/dispatch'] = (_) => const ApiResponse(statusCode: 409);
    expect(await fillDispatch(tester), 'failed');
    expect(find.textContaining('El servidor la rechazó'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing, reason: 'FAILED no se reintenta con el mismo Command-Id');
    await tap(tester, find.text('Nueva operación'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('form.carrierRef')), 'transportista-2');
    await tester.tap(find.byKey(const Key('form.submit')));
    await confirmAndClose(tester);
    final ids = posts().map((c) => c.headers['Command-Id']).toList();
    expect(ids.length, 2);
    expect(ids[0], isNot(ids[1]));
  });

  testWidgets('formulario con cambios + deep link: cancelar conserva el formulario y no consume el enlace', (
    tester,
  ) async {
    await openAsset(tester);
    await tap(tester, find.byKey(const Key('asset.action')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('form.carrierRef')), 'a medias');
    final link = h.services.deepLinkParser.parse(Uri.parse('$testOrigin/c/PUB1'));
    final consumed = h.services.router.openDeepLink(link);
    await tester.pumpAndSettle();
    expect(find.text('¿Salir sin enviar?'), findsOneWidget);
    await tester.tap(find.text('Seguir aquí'));
    await tester.pumpAndSettle();
    expect(await consumed, isFalse);
    expect(find.text('a medias'), findsOneWidget);
    expect(h.location, '/assets/A-1');
    expect(posts(), isEmpty);
  });

  testWidgets('formulario con cambios + deep link: salir descarta el formulario y consume el enlace', (tester) async {
    await openAsset(tester);
    await tap(tester, find.byKey(const Key('asset.action')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('form.carrierRef')), 'a medias');
    final consumed = h.services.router.openDeepLink(h.services.deepLinkParser.parse(Uri.parse('$testOrigin/c/PUB1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(await consumed, isTrue);
    expect(h.location, '/c/PUB1');
    expect(posts(), isEmpty);
  });

  testWidgets('E-11: QR del activo a pantalla completa, con la misma URL que la web y la referencia', (tester) async {
    await openAsset(tester);
    await tester.tap(find.byKey(const Key('asset.qr')));
    await tester.pumpAndSettle();
    expect(h.location, '/assets/A-1/qr');
    final qr = tester.widget<QrImageView>(find.byKey(const Key('assetqr.image')));
    expect(qr, isNotNull);
    expect(find.byKey(const Key('assetqr.ref')), findsOneWidget);
    expect(find.text('A-1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('assetqr.close')));
    await tester.pumpAndSettle();
    expect(h.location, '/assets/A-1');
  });

  testWidgets('sin acceso al activo (403) no se ofrece su QR', (tester) async {
    h = AppHarness();
    h.api.routes['GET /physical-assets/A-1'] = (_) => const ApiResponse(statusCode: 403);
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse()));
    h.services.router.push('/assets/A-1');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('asset.qr')), findsNothing);
  });

  testWidgets('DISPATCHED sin currentLocation (forma real del backend) → se muestra y ofrece Recibir', (tester) async {
    h = AppHarness();
    h.api.routes['GET /physical-assets/A-1'] = (_) => const ApiResponse(
      statusCode: 200,
      data: {
        'assetRef': 'A-1',
        'lifecycleStatus': 'DISPATCHED',
        'currentCustodianRef': 'transportista-1',
        'quantity': '1.0000',
        'unitOfMeasure': 'UNITS',
      },
    );
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse()));
    h.services.router.push('/assets/A-1');
    await tester.pumpAndSettle();
    expect(find.text('Despachado'), findsOneWidget);
    expect(find.text('Sin ubicación registrada'), findsOneWidget);
    expect(find.text('1 UNITS'), findsOneWidget, reason: '"1.0000" sin ceros sobrantes');
    expect(find.widgetWithText(FilledButton, 'Recibir'), findsOneWidget);
  });

  group('Entregar con foto (ADR-051)', () {
    final ref = 'sha256:${'c' * 64}';

    Future<void> fillDeliver(WidgetTester tester, {bool photo = true}) async {
      status = 'RECEIVED';
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const Key('asset.action')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('form.finalCustodianRef')), 'custodio-final');
      await tester.enterText(find.byKey(const Key('form.beneficiaryRef')), 'beneficiario-1');
      await tester.enterText(find.byKey(const Key('form.locationRef')), 'centro-1');
      if (photo) {
        await tap(tester, find.byKey(const Key('form.photo.take')));
        await tester.pumpAndSettle();
      }
      await tap(tester, find.byKey(const Key('form.submit')));
      await tester.pumpAndSettle();
    }

    Future<void> openReceived(WidgetTester tester) async {
      await openAsset(tester);
      status = 'RECEIVED';
      h.services.router.go('/operator');
      await tester.pumpAndSettle();
      h.services.router.push('/assets/A-1');
      await tester.pumpAndSettle();
    }

    testWidgets('sin foto no pasa a la revisión ni sube nada', (tester) async {
      await openReceived(tester);
      expect(find.widgetWithText(FilledButton, 'Entregar'), findsOneWidget);
      await fillDeliver(tester, photo: false);
      expect(find.byKey(const Key('form.photo.error')), findsOneWidget);
      expect(find.byKey(const Key('review.confirm')), findsNothing);
      expect(posts(), isEmpty);
    });

    testWidgets('sube la foto primero y la entrega lleva su evidenceRef', (tester) async {
      await openReceived(tester);
      h.api.routes['POST /organizations/org-1/delivery-evidence'] = (_) =>
          ApiResponse(statusCode: 201, data: {'evidenceRef': ref});
      h.api.routes['POST /physical-assets/A-1/deliver'] = (_) {
        status = 'DELIVERED';
        return const ApiResponse(statusCode: 200, data: {'assetRef': 'A-1', 'status': 'DELIVERED'});
      };
      await fillDeliver(tester);
      expect(find.byKey(const Key('review.photo')), findsOneWidget);
      expect(await confirmAndClose(tester), 'acknowledged');

      final calls = posts().toList();
      expect(calls.map((c) => c.path), ['/organizations/org-1/delivery-evidence', '/physical-assets/A-1/deliver']);
      final upload = calls.first;
      expect(upload.body, {'field': 'file', 'filename': 'entrega.jpg', 'contentType': 'image/jpeg', 'length': 4});
      expect(upload.credentialMode, CredentialMode.jwt);
      expect(upload.headers.containsKey('Command-Id'), isFalse, reason: 'la subida no lleva Command-Id');
      final deliver = calls.last;
      expect(deliver.body, {
        'finalCustodianRef': 'custodio-final',
        'beneficiaryRef': 'beneficiario-1',
        'locationRef': 'centro-1',
        'evidenceRef': ref,
      });
      expect(deliver.headers['Command-Id'], isNotNull);
    });

    testWidgets('sin conexión al subir la foto: no se registra nada ni se guarda en el teléfono', (tester) async {
      await openReceived(tester);
      h.api.routes['POST /organizations/org-1/delivery-evidence'] = (_) => const ConnectionNotEstablishedException();
      await fillDeliver(tester);
      await tester.tap(find.byKey(const Key('review.confirm')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Para entregar necesitas conexión'), findsOneWidget);
      expect(posts().where((c) => c.path.endsWith('/deliver')), isEmpty);
      expect(await h.services.syncEngine.entriesFor('acc-1'), isEmpty);
    });

    testWidgets('foto demasiado grande (413): pide otra', (tester) async {
      await openReceived(tester);
      h.api.routes['POST /organizations/org-1/delivery-evidence'] = (_) =>
          const ApiResponse(statusCode: 413, data: {'title': 'ImageTooLarge', 'status': 413});
      await fillDeliver(tester);
      await tester.tap(find.byKey(const Key('review.confirm')));
      await tester.pumpAndSettle();
      expect(find.text('La foto es demasiado grande. Toma otra.'), findsOneWidget);
      expect(posts().where((c) => c.path.endsWith('/deliver')), isEmpty);
    });

    testWidgets('si la entrega falla tras subir la foto, al reintentar no se vuelve a subir', (tester) async {
      await openReceived(tester);
      var uploads = 0;
      h.api.routes['POST /organizations/org-1/delivery-evidence'] = (_) {
        uploads++;
        return ApiResponse(statusCode: 201, data: {'evidenceRef': ref});
      };
      h.api.routes['POST /physical-assets/A-1/deliver'] = (_) => const ConnectionNotEstablishedException();
      await fillDeliver(tester);
      expect(await confirmAndClose(tester), 'notSent');
      expect(uploads, 1);
      final saved = (await h.services.syncEngine.entriesFor('acc-1')).single;
      expect(saved.payload['evidenceRef'], ref, reason: 'en la cola va la huella, nunca la foto');
    });
  });
}
