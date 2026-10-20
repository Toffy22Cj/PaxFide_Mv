import 'package:flutter/material.dart';

import '../theme/pax_tokens.dart';

/// Logo oficial de PaxFide (M-35). La imagen tiene fondo blanco: va sobre una tarjeta blanca, también en modo oscuro.
class PaxLogo extends StatelessWidget {
  const PaxLogo({super.key, this.size = 120});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'PaxFide, donaciones que llegan',
    image: true,
    child: Container(
      key: const Key('pax.logo'),
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.04),
      decoration: BoxDecoration(color: PaxTokens.white, borderRadius: BorderRadius.circular(size * 0.18)),
      child: Image.asset('assets/images/paxfide_logo.png', fit: BoxFit.contain, excludeFromSemantics: true),
    ),
  );
}
