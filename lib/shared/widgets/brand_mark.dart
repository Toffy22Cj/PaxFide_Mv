import 'package:flutter/material.dart';

/// Emblema de PaxFide (el logo sin el texto), generado desde el logo oficial por `scripts/marca/generar-iconos.py`.
/// Decorativo: el nombre «PaxFide» va siempre al lado en texto, así que el lector de pantalla lo omite.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32});

  static const asset = 'assets/marca/paxfide_emblema.png';

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    key: const Key('brand.mark'),
    width: size,
    height: size,
    filterQuality: FilterQuality.medium,
    excludeFromSemantics: true,
  );
}
