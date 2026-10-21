import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/shared/theme/pax_theme.dart';
import 'package:paxfide_mobile/shared/theme/pax_tokens.dart';

/// Sistema de diseño: la paleta oficial es la única fuente de color de la app.
void main() {
  const tokensFile = 'lib/shared/theme/pax_tokens.dart';
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
  String rel(File f) => f.path.replaceAll('\\', '/');
  String code(File f) => f.readAsLinesSync().where((l) => !l.trimLeft().startsWith('//')).join('\n');

  test('los 14 tokens tienen exactamente los valores oficiales', () {
    const official = {
      'brand-green-900': 0xFF1B5141,
      'brand-green-800': 0xFF20604C,
      'brand-green-500': 0xFF4E9155,
      'brand-green-50': 0xFFEEF6EF,
      'brand-blue-800': 0xFF255E79,
      'brand-blue-700': 0xFF327DA2,
      'brand-blue-500': 0xFF3688B0,
      'brand-blue-50': 0xFFEBF5F9,
      'brand-yellow-900': 0xFF785008,
      'brand-yellow-400': 0xFFF3B544,
      'brand-yellow-50': 0xFFFDF4E2,
      'brand-neutral-700': 0xFF405656,
      'white': 0xFFFFFFFF,
      'danger-700': 0xFFB42318,
    };
    expect(PaxTokens.all.map((k, v) => MapEntry(k, v.toARGB32())), official);
  });

  test('ningún color escrito a mano fuera de pax_tokens.dart', () {
    final bad = <String>[];
    final literal = RegExp(r'Color\(0x|Color\.fromA?RGBO?\(|Colors\.(?!transparent\b)[a-zA-Z]');
    for (final f in files.where((f) => !rel(f).endsWith(tokensFile))) {
      final lines = code(f).split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (literal.hasMatch(lines[i])) bad.add('${rel(f)}: ${lines[i].trim()}');
      }
    }
    expect(bad, isEmpty, reason: 'Usa el tema (colorScheme) o PaxTokens');
  });

  /// Colores del esquema que no salen de [allowed] (un token, o un token con transparencia).
  List<String> outside(ColorScheme s, Iterable<Color> allowed) {
    final rgb = allowed.map((c) => c.toARGB32() & 0xFFFFFF).toSet();
    final colors = <String, Color>{
      'primary': s.primary,
      'onPrimary': s.onPrimary,
      'primaryContainer': s.primaryContainer,
      'onPrimaryContainer': s.onPrimaryContainer,
      'secondary': s.secondary,
      'onSecondary': s.onSecondary,
      'secondaryContainer': s.secondaryContainer,
      'onSecondaryContainer': s.onSecondaryContainer,
      'tertiary': s.tertiary,
      'onTertiary': s.onTertiary,
      'tertiaryContainer': s.tertiaryContainer,
      'onTertiaryContainer': s.onTertiaryContainer,
      'error': s.error,
      'onError': s.onError,
      'errorContainer': s.errorContainer,
      'onErrorContainer': s.onErrorContainer,
      'surface': s.surface,
      'onSurface': s.onSurface,
      'onSurfaceVariant': s.onSurfaceVariant,
      'surfaceContainerLowest': s.surfaceContainerLowest,
      'surfaceContainerLow': s.surfaceContainerLow,
      'surfaceContainer': s.surfaceContainer,
      'surfaceContainerHigh': s.surfaceContainerHigh,
      'surfaceContainerHighest': s.surfaceContainerHighest,
      'outline': s.outline,
      'outlineVariant': s.outlineVariant,
      'shadow': s.shadow,
      'scrim': s.scrim,
      'inverseSurface': s.inverseSurface,
      'onInverseSurface': s.onInverseSurface,
      'inversePrimary': s.inversePrimary,
      'surfaceTint': s.surfaceTint,
      'primaryFixed': s.primaryFixed,
      'secondaryFixed': s.secondaryFixed,
      'tertiaryFixed': s.tertiaryFixed,
      'surfaceDim': s.surfaceDim,
      'surfaceBright': s.surfaceBright,
    };
    return [
      for (final e in colors.entries)
        if (!rgb.contains(e.value.toARGB32() & 0xFFFFFF)) '${e.key}: ${e.value}',
    ];
  }

  test('el modo claro solo usa la paleta oficial', () {
    expect(outside(PaxTheme.lightScheme, PaxTokens.all.values), isEmpty);
  });

  test('el modo oscuro usa la paleta y sus inversos', () {
    expect(outside(PaxTheme.darkScheme, [...PaxDarkTokens.all.values, ...PaxTokens.all.values]), isEmpty);
  });

  test('el modo oscuro es la paleta en contraste oscuro: cada inverso tiene L → 1 − L', () {
    double lightness(Color c) {
      final mx = [c.r, c.g, c.b].reduce((a, b) => a > b ? a : b);
      final mn = [c.r, c.g, c.b].reduce((a, b) => a < b ? a : b);
      return (mx + mn) / 2;
    }

    for (final (token, inverse) in PaxDarkTokens.inverseOf) {
      expect(lightness(inverse), closeTo(1 - lightness(token), 0.02), reason: '$token → $inverse');
    }
  });

  test('el modo oscuro es oscuro: fondo y superficies casi negros', () {
    final s = PaxTheme.darkScheme;
    for (final c in [s.surface, s.surfaceContainerLow, s.surfaceContainer, s.surfaceContainerHigh]) {
      expect(c.computeLuminance(), lessThan(0.03), reason: '$c no es oscuro');
    }
    expect(PaxTheme.pageBackground(s).computeLuminance(), lessThan(0.01));
  });

  /// Contraste WCAG entre dos colores opacos.
  double contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
  }

  for (final (name, s) in [('claro', PaxTheme.lightScheme), ('oscuro', PaxTheme.darkScheme)]) {
    test('modo $name: el texto principal se lee (contraste AA ≥ 4,5)', () {
      expect(contrast(s.onSurface, s.surface), greaterThanOrEqualTo(4.5));
      expect(contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5));
      expect(contrast(s.onErrorContainer, s.errorContainer), greaterThanOrEqualTo(4.5));
      expect(contrast(s.onSecondaryContainer, s.secondaryContainer), greaterThanOrEqualTo(4.5));
      expect(contrast(s.onTertiaryContainer, s.tertiaryContainer), greaterThanOrEqualTo(4.5));
      expect(contrast(s.primary, PaxTheme.pageBackground(s)), greaterThanOrEqualTo(4.5));
    });
  }
}
