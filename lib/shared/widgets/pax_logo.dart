import 'package:flutter/material.dart';

/// Logo de PaxFide (M-35): el emblema del logo oficial (el sol, el corazón verde y azul que abrazan una caja, la hoja
/// y la mano), sin el texto y sin fondo, así que se integra con el fondo en claro y en oscuro. Lo genera
/// `scripts/marca/generar-iconos.py` desde `Documentos/marca/paxfide-logo-original.webp`, en 1x, 2.0x y 3.0x
/// (128, 256 y 384 px: nítido hasta 128 dp).
class PaxLogo extends StatelessWidget {
  const PaxLogo({super.key, this.size = 120});
  final double size;

  static const asset = 'assets/marca/paxfide_emblema.png';

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'PaxFide, donaciones que llegan',
    image: true,
    child: SizedBox(
      key: const Key('pax.logo'),
      width: size,
      height: size,
      child: Image.asset(asset, width: size, height: size, filterQuality: FilterQuality.medium, excludeFromSemantics: true),
    ),
  );
}
