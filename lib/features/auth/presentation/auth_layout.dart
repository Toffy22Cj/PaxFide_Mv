import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/text_size_button.dart';
import '../../../app/theme_mode_button.dart';
import '../../../shared/theme/pax_tokens.dart';
import '../../../shared/widgets/pax_app_bar.dart';
import '../../../shared/widgets/pax_logo.dart';
import '../../../shared/widgets/loaders.dart';
import '../../welcome/presentation/welcome_world.dart';

/// Pestaña activa de la caja de acceso.
enum AuthTab { login, register }

/// Colores de la caja de acceso del landing (`.auth-card`), en claro y en oscuro (`night-auth`). Solo paleta.
class AuthInk {
  AuthInk(this.dark);
  final bool dark;

  static Color _mx(Color top, double a, Color base) => Color.alphaBlend(top.withValues(alpha: a), base);

  Color get title => dark ? PaxTokens.white : PaxTokens.brandGreen900;
  Color get body => dark ? PaxTokens.white.withValues(alpha: 0.75) : PaxTokens.brandNeutral700;
  Color get muted =>
      dark ? PaxTokens.white.withValues(alpha: 0.6) : _mx(PaxTokens.brandNeutral700, 0.7, PaxTokens.white);
  Color get line => dark ? PaxTokens.white.withValues(alpha: 0.14) : PaxTokens.brandGreen900.withValues(alpha: 0.12);
  Color get card => dark ? PaxDarkTokens.surface.withValues(alpha: 0.96) : PaxTokens.white.withValues(alpha: 0.95);
  Color get cardEdge =>
      dark ? PaxTokens.brandGreen500.withValues(alpha: 0.28) : PaxTokens.brandGreen900.withValues(alpha: 0.16);
  Color get field => dark ? PaxTokens.white.withValues(alpha: 0.07) : _mx(PaxTokens.brandGreen50, 0.8, PaxTokens.white);
  Color get fieldEdge =>
      dark ? PaxTokens.white.withValues(alpha: 0.18) : PaxTokens.brandGreen900.withValues(alpha: 0.18);
  Color get focus => dark ? PaxDarkTokens.green : PaxTokens.brandGreen900;
  Color get link => dark ? PaxDarkTokens.green : PaxTokens.brandGreen800;
  Color get button => dark ? PaxDarkTokens.green : PaxTokens.brandGreen900;
  Color get onButton => dark ? PaxDarkTokens.ink : PaxTokens.white;
  Color get tabs => dark ? PaxTokens.white.withValues(alpha: 0.08) : PaxTokens.brandGreen900.withValues(alpha: 0.07);
  Color get tabOn => dark ? PaxTokens.white.withValues(alpha: 0.18) : PaxTokens.white;
}

/// Vista de acceso del landing (`#authView`) adaptada al móvil: el mundo ilustrado de fondo, sin desenfoque; arriba la
/// píldora «Volver» y la del tema; en el centro, **una sola caja** con la insignia «TU CUENTA PAXFIDE», el título, el
/// texto y las pestañas Iniciar sesión / Crear cuenta. [below] va fuera de la caja (accesos sin cuenta).
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.back = false,
    this.tab,
    this.footer,
    this.below,
  });

  final String title;
  final Widget child;
  final String? subtitle;
  final bool back;

  /// Pestañas Iniciar sesión / Crear cuenta; sin pestañas si es null.
  final AuthTab? tab;

  /// Pie de la caja («¿No tienes una cuenta aún? Regístrate gratis»).
  final Widget? footer;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = AuthInk(dark);
    final stack = services.router.stack;
    final fromWelcome = stack.length > 1 && stack[stack.length - 2] == AppRoutes.welcome;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        // El teclado no encoge la pantalla: si lo hiciera, el mundo de fondo cambiaría de tamaño y se volvería a
        // pintar entero en cada fotograma de la animación del teclado. El hueco del teclado se deja abajo (ver
        // `viewInsets`), solo para el contenido.
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(child: _World(dark: dark)),
            SafeArea(
              child: Column(
                children: [
                  // Barra de arriba (landing `.auth-top-bar`): en el móvil se queda fija sobre la caja.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (back)
                          Flexible(
                            child: Tooltip(
                              message: 'Volver',
                              child: _Pill(
                                key: const Key('auth.back'),
                                onTap: services.router.back,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.arrow_back, size: 20, color: ink.title),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        fromWelcome ? 'Volver al recorrido' : 'Volver',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: ink.title),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          const Flexible(
                            child: _Pill(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PaxLogo(size: 28),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: FittedBox(fit: BoxFit.scaleDown, child: PaxWordmark(size: 18)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        const _Pill(
                          padding: EdgeInsets.symmetric(horizontal: 2),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [TextSizeButton(), ThemeModeButton()]),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _KeyboardGap(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _Card(
                                  ink: ink,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: AuthBadge(ink: ink),
                                      ),
                                      const SizedBox(height: 12),
                                      Semantics(
                                        header: true,
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.7,
                                            height: 1.1,
                                            color: ink.title,
                                          ),
                                        ),
                                      ),
                                      if (subtitle != null) ...[
                                        const SizedBox(height: 8),
                                        Text(subtitle!, style: TextStyle(fontSize: 14, height: 1.45, color: ink.body)),
                                      ],
                                      const SizedBox(height: 20),
                                      if (tab != null) ...[_Tabs(ink: ink, tab: tab!), const SizedBox(height: 20)],
                                      child,
                                      if (footer != null) ...[
                                        const SizedBox(height: 20),
                                        Divider(height: 1, color: ink.line),
                                        const SizedBox(height: 14),
                                        footer!,
                                      ],
                                    ],
                                  ),
                                ),
                                ?below,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El mundo del landing, quieto, detrás de la caja (de día, o de noche en modo oscuro).
class _World extends StatefulWidget {
  const _World({required this.dark});
  final bool dark;

  @override
  State<_World> createState() => _WorldState();
}

class _WorldState extends State<_World> {
  final _clock = WorldClock();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clock.set(camS: 0.35, t: 0, night: widget.dark ? 1 : 0);
    return WelcomeWorldView(clock: _clock);
  }
}

/// Píldora de vidrio de la barra de arriba (`.auth-back-btn`, `.theme-toggle`).
class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.child, this.onTap, this.padding});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => PaxGlass(
    radius: 999,
    opacity: 0.95,
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: padding ?? const EdgeInsets.fromLTRB(14, 6, 18, 6),
            child: Center(widthFactor: 1, child: child),
          ),
        ),
      ),
    ),
  );
}

/// La caja única (`.auth-card`): casi opaca, esquinas de 22 en el móvil, borde fino y sombra larga. Entra con un leve
/// zoom, como en el landing.
class _Card extends StatelessWidget {
  const _Card({required this.ink, required this.child});
  final AuthInk ink;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: PaxTokens.brandGreen900.withValues(alpha: ink.dark ? 0.5 : 0.16),
            blurRadius: 64,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      // Sin desenfoque del fondo: la caja es casi opaca (95 %) y el desenfoque, que se recalculaba en cada fotograma
      // (cursor, teclado), no se notaba.
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
        decoration: BoxDecoration(
          color: ink.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: ink.cardEdge),
        ),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return card;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: const Cubic(0.16, 1, 0.3, 1),
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - v)),
          child: Transform.scale(scale: 0.97 + 0.03 * v, child: child),
        ),
      ),
      child: card,
    );
  }
}

/// «TU CUENTA PAXFIDE» con el punto verde (`.auth-badge-pill`).
class AuthBadge extends StatelessWidget {
  const AuthBadge({super.key, required this.ink});
  final AuthInk ink;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: PaxTokens.brandGreen500.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: PaxTokens.brandGreen500.withValues(alpha: 0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: PaxTokens.brandGreen500,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: PaxTokens.brandGreen500.withValues(alpha: 0.3), spreadRadius: 2)],
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            'TU CUENTA PAXFIDE',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: ink.dark ? PaxDarkTokens.green : PaxTokens.brandGreen900,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Pestañas Iniciar sesión / Crear cuenta dentro de la caja (`.auth-tabs`). Cada una es su propia pantalla
/// (`/login`, `/register`): la otra pestaña vuelve o abre la otra ruta.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.ink, required this.tab});
  final AuthInk ink;
  final AuthTab tab;

  @override
  Widget build(BuildContext context) {
    final router = AppScope.of(context).router;
    void open(AuthTab t) {
      if (t == tab) return;
      final target = t == AuthTab.login ? AppRoutes.login : AppRoutes.register;
      final stack = router.stack;
      if (stack.length > 1 && stack[stack.length - 2] == target) {
        router.back();
      } else {
        router.push(target);
      }
    }

    Widget item(AuthTab t, IconData icon, String label) {
      final on = t == tab;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          child: Material(
            color: on ? ink.tabOn : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            elevation: 0,
            shadowColor: Colors.transparent,
            child: InkWell(
              key: Key('auth.tab.${t.name}'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => open(t),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 42),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 16, color: on ? ink.title : ink.body),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? ink.title : ink.body),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: ink.tabs, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          item(AuthTab.login, Icons.login, 'Iniciar Sesión'),
          const SizedBox(width: 6),
          item(AuthTab.register, Icons.person_add_alt_1_outlined, 'Crear Cuenta'),
        ],
      ),
    );
  }
}

/// Decoración de los campos de la caja (`.auth-input-wrap`): ícono a la izquierda, 44 de alto, esquinas de 12.
InputDecoration authInput(AuthInk ink, {required IconData icon, String? hint, Widget? suffix, String? helper}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    filled: true,
    fillColor: ink.field,
    hintText: hint,
    hintStyle: TextStyle(color: ink.muted, fontWeight: FontWeight.w500),
    helperText: helper,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    prefixIcon: Icon(icon, size: 20, color: ink.muted),
    suffixIcon: suffix,
    enabledBorder: border(ink.fieldEdge),
    disabledBorder: border(ink.fieldEdge),
    focusedBorder: border(ink.focus, 1.6),
    errorBorder: border(ink.dark ? PaxDarkTokens.danger : PaxTokens.danger700),
    border: border(ink.fieldEdge),
  );
}

/// Etiqueta encima del campo (`.auth-field label`), con algo a la derecha opcional («¿Olvidaste tu contraseña?»).
class AuthField extends StatelessWidget {
  const AuthField({super.key, required this.label, required this.child, this.trailing, required this.ink});
  final String label;
  final Widget child;
  final Widget? trailing;
  final AuthInk ink;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      // Con texto grande, el enlace de la derecha baja a su propia línea en vez de desbordar.
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ink.title),
          ),
          ?trailing,
        ],
      ),
      const SizedBox(height: 6),
      child,
    ],
  );
}

/// Campo de contraseña con el candado y el ojo para mostrarla u ocultarla.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.ink,
    this.enabled = true,
    this.hint,
    this.helperText,
    this.onSubmitted,
    this.onChanged,
    this.autofillHints,
  });
  final TextEditingController controller;
  final AuthInk ink;
  final bool enabled;
  final String? hint;
  final String? helperText;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    enabled: widget.enabled,
    obscureText: _hidden,
    autofillHints: widget.autofillHints,
    onSubmitted: widget.onSubmitted,
    onChanged: widget.onChanged,
    style: TextStyle(color: widget.ink.title, fontWeight: FontWeight.w500),
    decoration: authInput(
      widget.ink,
      icon: Icons.lock_outline,
      hint: widget.hint,
      helper: widget.helperText,
      suffix: IconButton(
        tooltip: _hidden ? 'Mostrar contraseña' : 'Ocultar contraseña',
        icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: widget.ink.muted),
        onPressed: () => setState(() => _hidden = !_hidden),
      ),
    ),
  );
}

/// Tipo de aviso de la caja (`.auth-feedback-msg`).
enum AuthNoticeKind { success, error }

/// Aviso de la caja: verde (hecho) o rojo (error).
class AuthNotice extends StatelessWidget {
  const AuthNotice(this.text, {super.key, this.kind = AuthNoticeKind.error, this.textKey, required this.ink});
  final String text;
  final AuthNoticeKind kind;
  final Key? textKey;
  final AuthInk ink;

  @override
  Widget build(BuildContext context) {
    final (bg, edge, fg) = switch (kind) {
      AuthNoticeKind.success => (
        PaxTokens.brandGreen500.withValues(alpha: 0.16),
        PaxTokens.brandGreen500.withValues(alpha: 0.35),
        ink.dark ? PaxDarkTokens.green : PaxTokens.brandGreen900,
      ),
      AuthNoticeKind.error => (
        PaxTokens.danger700.withValues(alpha: 0.1),
        PaxTokens.danger700.withValues(alpha: 0.3),
        ink.dark ? PaxDarkTokens.danger : PaxTokens.danger700,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: edge),
        ),
        child: Text(
          text,
          key: textKey,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600, color: fg),
        ),
      ),
    );
  }
}

/// Botón principal de la caja (`.auth-submit-btn`): verde oscuro, 46 de alto, esquinas de 14, con su ícono.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.ink,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
  });
  final AuthInk ink;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: ink.button,
      foregroundColor: ink.onButton,
      // Mientras envía no se ve gris: conserva su color con los puntos de marca (como la web).
      disabledBackgroundColor: busy ? ink.button : null,
      disabledForegroundColor: busy ? ink.onButton : null,
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
    ),
    child: busy
        ? BrandDots(color: ink.onButton)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 18),
            ],
          ),
  );
}

/// Botón secundario de la caja (`.social-auth-btn`): borde fino, fondo claro, 44 de alto, esquinas de 12.
class AuthOutlineButton extends StatelessWidget {
  const AuthOutlineButton({
    super.key,
    required this.ink,
    required this.label,
    required this.leading,
    required this.onPressed,
  });
  final AuthInk ink;
  final String label;
  final Widget leading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      backgroundColor: ink.dark ? PaxTokens.white.withValues(alpha: 0.08) : PaxTokens.white.withValues(alpha: 0.9),
      foregroundColor: ink.title,
      side: BorderSide(color: ink.dark ? PaxTokens.white.withValues(alpha: 0.18) : ink.fieldEdge),
      minimumSize: const Size(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leading,
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

/// Separador con texto en medio («o continúa con correo electrónico»).
class AuthDivider extends StatelessWidget {
  const AuthDivider(this.text, {super.key, required this.ink});
  final String text;
  final AuthInk ink;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Divider(color: ink.line)),
      Flexible(
        flex: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2, color: ink.muted),
          ),
        ),
      ),
      Expanded(child: Divider(color: ink.line)),
    ],
  );
}

/// Pie de la caja: «¿No tienes una cuenta aún? Regístrate gratis».
class AuthSwitch extends StatelessWidget {
  const AuthSwitch({
    super.key,
    required this.ink,
    required this.text,
    required this.action,
    this.onTap,
    this.actionKey,
  });
  final AuthInk ink;
  final String text;
  final String action;
  final VoidCallback? onTap;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(text, style: TextStyle(fontSize: 13.5, color: ink.body)),
      TextButton(
        key: actionKey,
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: ink.link, minimumSize: const Size(0, 44)),
        child: Text(
          action,
          style: const TextStyle(fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
        ),
      ),
    ],
  );
}

/// Deja abajo el hueco del teclado solo para el contenido. Es lo único que depende de `viewInsets`: en cada fotograma
/// del teclado se reconstruye esto, no la pantalla entera ni el mundo de fondo.
class _KeyboardGap extends StatelessWidget {
  const _KeyboardGap({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final safe = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard > safe ? keyboard - safe : 0),
      child: child,
    );
  }
}
