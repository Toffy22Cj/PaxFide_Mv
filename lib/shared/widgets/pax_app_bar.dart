import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/pax_tokens.dart';
import 'pax_logo.dart';

/// El «vidrio» del landing: superficie casi opaca con borde fino y sombra suave.
///
/// Rendimiento: **sin desenfoque del fondo** (`BackdropFilter`). Un desenfoque se recalcula en cada fotograma en que
/// algo se mueve en pantalla (el mundo animado de la bienvenida, el desplazamiento, el cursor), y varios a la vez eran
/// la causa principal del lag. Con la superficie al 95 % el desenfoque apenas se veía.
class PaxGlass extends StatelessWidget {
  const PaxGlass({super.key, required this.child, this.radius = 26, this.padding, this.opacity = 0.95});
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final dark = s.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        // En oscuro la sombra no se ve: no se dibuja (una sombra transparente también cuesta su desenfoque).
        boxShadow: dark
            ? null
            : [BoxShadow(color: s.primary.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: s.surface.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: (dark ? s.outline : s.primary).withValues(alpha: dark ? 0.3 : 0.14)),
        ),
        child: child,
      ),
    );
  }
}

/// "PaxFide." en los tres colores de la marca: Pax en verde, Fide en azul y el punto en amarillo.
class PaxWordmark extends StatelessWidget {
  const PaxWordmark({super.key, this.size = 21});
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, letterSpacing: -0.02 * size, height: 1),
        children: [
          TextSpan(
            text: 'Pax',
            style: TextStyle(color: dark ? PaxTokens.brandGreen50 : PaxTokens.brandGreen900),
          ),
          TextSpan(
            text: 'Fide',
            style: TextStyle(color: dark ? PaxDarkTokens.blue : PaxTokens.brandBlue700),
          ),
          const TextSpan(
            text: '.',
            style: TextStyle(color: PaxTokens.brandYellow400),
          ),
        ],
      ),
      semanticsLabel: 'PaxFide',
      maxLines: 1,
    );
  }
}

/// Barra superior de toda la app, como la del landing: una píldora flotante de vidrio esmerilado con el logo (o volver),
/// el título y las acciones. Misma forma de uso que `AppBar` (`title`, `leading`, `automaticallyImplyLeading`,
/// `actions`).
class PaxAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PaxAppBar({super.key, this.title, this.leading, this.automaticallyImplyLeading = true, this.actions});
  final Widget? title;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final List<Widget>? actions;

  /// Alto de la barra sin el margen superior del sistema.
  static const double height = 74;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = theme.colorScheme;
    final route = ModalRoute.of(context);
    Widget? lead = leading;
    if (lead == null && automaticallyImplyLeading && (route?.impliesAppBarDismissal ?? false)) {
      lead = route is PageRoute && route.fullscreenDialog ? const CloseButton() : const BackButton();
    }
    lead ??= const Padding(padding: EdgeInsets.only(left: 6), child: PaxLogo(size: 34));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: s.brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: PaxGlass(
              radius: 999,
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
              child: SizedBox(
                height: 52,
                child: IconTheme.merge(
                  data: IconThemeData(color: s.onSurface),
                  child: Row(
                    children: [
                      lead,
                      const SizedBox(width: 10),
                      Expanded(
                        child: DefaultTextStyle(
                          style: (theme.textTheme.titleLarge ?? const TextStyle()).copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: s.brightness == Brightness.dark ? PaxTokens.brandGreen50 : PaxTokens.brandGreen900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          child: Semantics(header: true, child: title ?? const SizedBox.shrink()),
                        ),
                      ),
                      ...?actions,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
