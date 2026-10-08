import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D2: dependencia estricta `presentation → domain → data → core`, nunca invertida.
/// Lee los `import` de lib/ y falla si alguno va en sentido contrario.
void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  final importRe = RegExp(r'''^import\s+['"]([^'"]+)['"]''', multiLine: true);

  /// Ruta normalizada (relativa a lib/) de cada import interno del fichero.
  List<String> internalImports(File f) {
    final dir = f.absolute.parent.uri;
    final out = <String>[];
    for (final m in importRe.allMatches(f.readAsStringSync())) {
      final target = m.group(1)!;
      if (target.startsWith('package:paxfide_mobile/')) {
        out.add(target.substring('package:paxfide_mobile/'.length));
      } else if (!target.contains(':')) {
        final resolved = dir.resolve(target).path;
        final i = resolved.indexOf('/lib/');
        out.add(i >= 0 ? resolved.substring(i + 5) : resolved);
      }
    }
    return out;
  }

  String rel(File f) => f.path.replaceAll('\\', '/').split('lib/').last;

  test('hay código que auditar', () => expect(files, isNotEmpty));

  test('core no importa app ni features', () {
    final bad = <String>[];
    for (final f in files.where((f) => rel(f).startsWith('core/'))) {
      for (final i in internalImports(f)) {
        if (i.startsWith('app/') || i.startsWith('features/') || i.startsWith('shared/')) {
          bad.add('${rel(f)} → $i');
        }
      }
    }
    expect(bad, isEmpty);
  });

  test('data no importa domain ni presentation; domain no importa presentation', () {
    final bad = <String>[];
    for (final f in files.where((f) => rel(f).startsWith('features/'))) {
      final layer = rel(f).split('/')[2];
      for (final i in internalImports(f)) {
        if (!i.startsWith('features/')) continue;
        final target = i.split('/')[2];
        if (layer == 'data' && (target == 'domain' || target == 'presentation')) bad.add('${rel(f)} → $i');
        if (layer == 'domain' && target == 'presentation') bad.add('${rel(f)} → $i');
      }
    }
    expect(bad, isEmpty);
  });

  test('ninguna capa de features importa app/ salvo presentation', () {
    final bad = <String>[];
    for (final f in files.where((f) => rel(f).startsWith('features/'))) {
      final layer = rel(f).split('/')[2];
      if (layer == 'presentation') continue;
      for (final i in internalImports(f)) {
        if (i.startsWith('app/')) bad.add('${rel(f)} → $i');
      }
    }
    expect(bad, isEmpty);
  });

  test('D3: nadie decodifica el JWT (sin base64 sobre el token)', () {
    final bad = files
        .where((f) => RegExp(r'base64(Url)?\.decode|base64Url', caseSensitive: false).hasMatch(f.readAsStringSync()))
        .map(rel)
        .toList();
    expect(bad, isEmpty);
  });
}
