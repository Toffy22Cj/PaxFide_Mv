// Enmienda 7 de ADR-043 (PROPUESTA): foto OPCIONAL al despachar y recibir.
// ESTAS PRUEBAS NO SE HAN EJECUTADO: el entorno donde se escribieron no tiene Flutter. Las corre Adonis
// (`flutter analyze` y `flutter test`) y pega la salida literal en el PR.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/core/storage/outbox_file_store.dart';

import '../support/app_harness.dart';

final _ref = 'sha256:${'d' * 64}';

ApiResponse _asset(String status) => ApiResponse(
  statusCode: 200,
  data: {
    'assetRef': 'A-1',
    'lifecycleStatus': status,
    'assetType': 'BLANKET',
    'currentCustodianRef': 'bodega-1',
    'currentLocation': 'bodega-1',
    'quantity': '10',
    'unitOfMeasure': 'kg',
  },
);

Future<void> _pickMunicipality(WidgetTester tester, String query, String code) async {
  await tester.ensureVisible(find.byKey(const Key('form.municipality')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('form.municipality')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('municipality.search')), query);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('municipality.$code')));
  await tester.pumpAndSettle();
}

void main() {
  late AppHarness h;
  late String status;

  Future<void> open(WidgetTester tester, String initial) async {
    h = AppHarness();
    status = initial;
    h.api.routes['GET /physical-assets/A-1'] = (_) => _asset(status);
    h.api.routes['POST /physical-assets/A-1/dispatch'] = (_) {
      status = 'DISPATCHED';
      return const ApiResponse(statusCode: 200, data: {'assetRef': 'A-1', 'status': 'DISPATCHED'});
    };
    h.api.routes['POST /physical-assets/A-1/receive'] = (_) {
      status = 'RECEIVED';
      return const ApiResponse(statusCode: 200, data: {'assetRef': 'A-1', 'status': 'RECEIVED'});
    };
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse()));
    h.services.router.push('/assets/A-1');
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    if (f.evaluate().isEmpty) {
      final list = find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(f, 200, scrollable: list);
    }
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
  }

  Iterable<dynamic> posts() => h.api.calls.where((c) => c.method == 'POST');

  /// Abre el formulario del paso y llena lo obligatorio; [photo] toma la foto (cámara simulada).
  Future<void> fill(WidgetTester tester, {required bool dispatch, bool photo = false}) async {
    await tap(tester, find.byKey(const Key('asset.action')));
    await tester.pumpAndSettle();
    if (dispatch) {
      await tester.enterText(find.byKey(const Key('form.carrierRef')), 'transportista-1');
    } else {
      await tester.enterText(find.byKey(const Key('form.facilityLocation')), 'bodega-norte');
      await tester.enterText(find.byKey(const Key('form.receiverRef')), 'coordinador-1');
      await _pickMunicipality(tester, 'cartag', '13001');
    }
    if (photo) {
      await tap(tester, find.byKey(const Key('form.photo.take')));
      await tester.pumpAndSettle();
    }
    await tap(tester, find.byKey(const Key('form.submit')));
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('review.confirm')));
    await tester.pumpAndSettle();
  }

  group('Despachar con foto opcional', () {
    testWidgets('SIN foto: no se sube nada y el cuerpo NO lleva evidenceRef', (tester) async {
      await open(tester, 'REGISTERED');
      await fill(tester, dispatch: true);
      await confirm(tester);
      expect(posts().map((c) => c.path), ['/physical-assets/A-1/dispatch']);
      expect(posts().single.body, {'carrierRef': 'transportista-1'});
      expect(h.photos.calls, 0);
    });

    testWidgets('CON foto: primero la subida (paso DISPATCHED, sin Command-Id), después el comando con su evidenceRef', (
      tester,
    ) async {
      await open(tester, 'REGISTERED');
      h.api.routes['POST /organizations/org-1/asset-evidence'] = (_) =>
          ApiResponse(statusCode: 201, data: {'evidenceRef': _ref});
      await fill(tester, dispatch: true, photo: true);
      expect(find.byKey(const Key('review.photo')), findsOneWidget);
      await confirm(tester);
      final calls = posts().toList();
      expect(calls.map((c) => c.path), ['/organizations/org-1/asset-evidence', '/physical-assets/A-1/dispatch']);
      final upload = calls.first;
      expect(upload.body, {
        'field': 'file',
        'filename': 'entrega.jpg',
        'contentType': 'image/jpeg',
        'length': 4,
        'fields': {'step': 'DISPATCHED'},
      });
      expect(upload.credentialMode, CredentialMode.jwt);
      expect(upload.headers.containsKey('Command-Id'), isFalse);
      expect(calls.last.body, {'carrierRef': 'transportista-1', 'evidenceRef': _ref});
    });

    testWidgets('quitar la foto antes de confirmar: no se sube y el cuerpo no la lleva', (tester) async {
      await open(tester, 'REGISTERED');
      await tap(tester, find.byKey(const Key('asset.action')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('form.carrierRef')), 'transportista-1');
      await tap(tester, find.byKey(const Key('form.photo.take')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('form.photo.preview')), findsOneWidget);
      await tap(tester, find.byKey(const Key('form.photo.remove')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('form.photo.preview')), findsNothing);
      await tap(tester, find.byKey(const Key('form.submit')));
      await tester.pumpAndSettle();
      await confirm(tester);
      expect(posts().map((c) => c.path), ['/physical-assets/A-1/dispatch']);
      expect(posts().single.body, {'carrierRef': 'transportista-1'});
    });

    for (final (code, title, text) in [
      (413, 'ImageTooLarge', 'demasiado grande'),
      (415, 'UnsupportedImageFormat', 'JPEG o PNG'),
      (503, 'MediaStorageUnavailable', 'almacenamiento de fotos'),
      (410, 'EvidenceRemoved', 'retirada'),
    ]) {
      testWidgets('la subida da $code: dice por qué, el comando NO sale y «Seguir sin foto» lo deja confirmar', (
        tester,
      ) async {
        await open(tester, 'REGISTERED');
        h.api.routes['POST /organizations/org-1/asset-evidence'] = (_) =>
            ApiResponse(statusCode: code, data: {'title': title});
        await fill(tester, dispatch: true, photo: true);
        await confirm(tester);
        expect(find.textContaining(text), findsWidgets);
        expect(posts().map((c) => c.path), ['/organizations/org-1/asset-evidence'], reason: 'el comando no salió');
        await tap(tester, find.byKey(const Key('review.skipPhoto')));
        await tester.pumpAndSettle();
        await confirm(tester);
        expect(posts().last.path, '/physical-assets/A-1/dispatch');
        expect(posts().last.body, {'carrierRef': 'transportista-1'}, reason: 'sin foto, sin evidenceRef');
      });
    }

    testWidgets('sin red al subir: el paso sale SIN foto y lo dice; la cola no guarda bytes de imagen', (tester) async {
      await open(tester, 'REGISTERED');
      h.api.routes['POST /organizations/org-1/asset-evidence'] = (_) => const NetworkTimeoutException();
      await fill(tester, dispatch: true, photo: true);
      await confirm(tester);
      expect(find.byKey(const Key('result.photoDropped')), findsOneWidget);
      expect(posts().last.path, '/physical-assets/A-1/dispatch');
      expect(posts().last.body, {'carrierRef': 'transportista-1'});
      expect(
        h.secure.values.keys.where((k) => k.startsWith(OutboxFileStore.prefix)),
        isEmpty,
        reason: 'ni un archivo de la foto en el almacén de la cola',
      );
    });

    testWidgets('un reintento tras un rechazo del comando NO sube otra vez la misma foto y lleva la misma evidenceRef', (
      tester,
    ) async {
      await open(tester, 'REGISTERED');
      var uploads = 0;
      h.api.routes['POST /organizations/org-1/asset-evidence'] = (_) {
        uploads++;
        return ApiResponse(statusCode: 201, data: {'evidenceRef': _ref});
      };
      var first = true;
      h.api.routes['POST /physical-assets/A-1/dispatch'] = (_) {
        if (first) {
          first = false;
          throw const NetworkTimeoutException();
        }
        status = 'DISPATCHED';
        return const ApiResponse(statusCode: 200, data: {'assetRef': 'A-1', 'status': 'DISPATCHED'});
      };
      await fill(tester, dispatch: true, photo: true);
      await confirm(tester);
      // el comando quedó ambiguo (red); la foto ya estaba subida
      expect(uploads, 1);
      final dispatches = posts().where((c) => c.path == '/physical-assets/A-1/dispatch').toList();
      expect(dispatches.single.body, {'carrierRef': 'transportista-1', 'evidenceRef': _ref});
    });
  });

  group('Recibir con foto opcional', () {
    testWidgets('con foto: paso RECEIVED y evidenceRef junto al municipio; sin foto, ninguna de las dos cosas extra', (
      tester,
    ) async {
      await open(tester, 'DISPATCHED');
      h.api.routes['POST /organizations/org-1/asset-evidence'] = (_) =>
          ApiResponse(statusCode: 201, data: {'evidenceRef': _ref});
      await fill(tester, dispatch: false, photo: true);
      await confirm(tester);
      final calls = posts().toList();
      expect(calls.first.body['fields'], {'step': 'RECEIVED'});
      expect(calls.last.body, {
        'facilityLocation': 'bodega-norte',
        'receiverRef': 'coordinador-1',
        'evidenceRef': _ref,
        'municipalityCode': '13001',
      });
    });

    testWidgets('SIN foto: el cuerpo es el de siempre', (tester) async {
      await open(tester, 'DISPATCHED');
      await fill(tester, dispatch: false);
      await confirm(tester);
      expect(posts().map((c) => c.path), ['/physical-assets/A-1/receive']);
      expect(posts().single.body, {
        'facilityLocation': 'bodega-norte',
        'receiverRef': 'coordinador-1',
        'municipalityCode': '13001',
      });
    });
  });

  group('La entrega no cambia', () {
    testWidgets('sigue exigiendo su foto (obligatoria) y el botón dice «Tomar foto», no «opcional»', (tester) async {
      await open(tester, 'RECEIVED');
      await tap(tester, find.byKey(const Key('asset.action')));
      await tester.pumpAndSettle();
      expect(find.text('Foto de la entrega'), findsOneWidget);
      expect(find.text('Foto (opcional)'), findsNothing);
      expect(find.byKey(const Key('form.photo.remove')), findsNothing);
    });
  });
}
