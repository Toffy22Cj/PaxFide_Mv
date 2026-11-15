import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/motion/pax_motion.dart';
import '../../../shared/theme/pax_tokens.dart';
import '../../../shared/widgets/error_message.dart';
import '../../../shared/widgets/loaders.dart';
import '../../../shared/widgets/pax_logo.dart';
import '../../../shared/widgets/pax_ui.dart';
import '../data/account_api.dart';

/// Primeros pasos tras crear la cuenta (web: bienvenida de `LoginScreen` y `NameGate`; `paxfide-home.html`): qué se
/// puede hacer en PaxFide y, después, «¿Cómo te llamamos?» (opcional: «Más tarde» no guarda nada). El nombre solo
/// viaja en `PUT /account/profile`. Los pasos cambian con el «eje Z» de `movimiento.html`.
class FirstStepsScreen extends StatefulWidget {
  const FirstStepsScreen({super.key});

  @override
  State<FirstStepsScreen> createState() => _FirstStepsScreenState();
}

class _FirstStepsScreenState extends State<FirstStepsScreen> {
  bool _nameStep = false;

  void _done() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: PaxMotion.of(context, PaxMotion.normal),
          switchInCurve: PaxMotion.standard,
          switchOutCurve: PaxMotion.standard,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(a), child: child),
          ),
          child: _nameStep
              ? _NameStep(key: const ValueKey('name'), onDone: _done)
              : _WelcomeStep(key: const ValueKey('welcome'), onContinue: () => setState(() => _nameStep = true)),
        ),
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.step, required this.children});
  final int step;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        Row(
          children: [
            const PaxLogo(size: 32),
            const SizedBox(width: 8),
            Text('PaxFide', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 24),
        ...children,
        const SizedBox(height: 20),
        // Tres puntos: en qué paso está (bienvenida, nombre, la app).
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                AnimatedContainer(
                  duration: PaxMotion.of(context, PaxMotion.normal),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == step ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == step ? s.primary : s.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Frame(
      step: 0,
      children: [
        const Center(
          child: ExcludeSemantics(
            child: CustomPaint(size: Size(250, 64), painter: _SealedChainPainter()),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Te damos la bienvenida a PaxFide',
          key: const Key('firstSteps.welcome'),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Ya iniciaste sesión. Esto es lo que puedes hacer aquí:',
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        const _Feature(
          icon: Icons.favorite_border,
          color: PaxTokens.brandGreen800,
          tint: PaxTokens.brandGreen50,
          title: 'Dona a convocatorias verificadas',
          text: 'Cada organización pasa por una revisión antes de publicar.',
        ),
        const _Feature(
          icon: Icons.route_outlined,
          color: PaxTokens.brandBlue800,
          tint: PaxTokens.brandBlue50,
          title: 'Sigue el recorrido de tu ayuda',
          text: 'Del pago a la compra, el despacho y la entrega.',
        ),
        const _Feature(
          icon: Icons.lock_outline,
          color: PaxTokens.brandYellow900,
          tint: PaxTokens.brandYellow50,
          title: 'Cada paso queda sellado',
          text: 'Se registra de forma que no se puede cambiar sin que se note.',
        ),
        const SizedBox(height: 16),
        FilledButton(key: const Key('firstSteps.continue'), onPressed: onContinue, child: const Text('Continuar')),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.color,
    required this.tint,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final Color color;
  final Color tint;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tres cubos encadenados (azul, verde, amarillo) y el candado: la cadena sellada de la web. Estática.
class _SealedChainPainter extends CustomPainter {
  const _SealedChainPainter();

  static const _cubes = [
    (PaxTokens.brandBlue500, PaxTokens.brandBlue800, PaxTokens.brandBlue700),
    (PaxTokens.brandGreen500, PaxTokens.brandGreen900, PaxTokens.brandGreen800),
    (PaxTokens.brandYellow400, PaxTokens.brandYellow900, PaxTokens.brandYellow400),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    const cube = 56.0, link = 14.0;
    for (var i = 0; i < 3; i++) {
      final x = i * (cube + link);
      final (top, left, right) = _cubes[i];
      Path poly(List<Offset> pts) => Path()..addPolygon([for (final o in pts) o.translate(x, 4)], true);
      canvas
        ..drawPath(poly(const [Offset(28, 6), Offset(48, 17), Offset(28, 28), Offset(8, 17)]), p..color = top)
        ..drawPath(poly(const [Offset(8, 17), Offset(28, 28), Offset(28, 50), Offset(8, 39)]), p..color = left)
        ..drawPath(
          poly(const [Offset(48, 17), Offset(28, 28), Offset(28, 50), Offset(48, 39)]),
          p..color = right.withValues(alpha: i == 2 ? 0.75 : 1),
        );
      if (i < 2) {
        canvas.drawRRect(
          RRect.fromLTRBR(x + cube - 4, 31, x + cube + link + 4, 35, const Radius.circular(2)),
          p..color = PaxTokens.brandBlue500.withValues(alpha: 0.5),
        );
      }
    }
    // El candado sobre el último cubo.
    final c = Offset(2 * (cube + link) + 48, 12);
    canvas
      ..drawCircle(c, 13, p..color = PaxTokens.brandGreen800)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c.translate(0, 2), width: 11, height: 8),
          const Radius.circular(2),
        ),
        p..color = PaxTokens.white,
      )
      ..drawArc(
        Rect.fromCenter(center: c.translate(0, -2), width: 8, height: 9),
        3.1416,
        3.1416,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = PaxTokens.white,
      );
  }

  @override
  bool shouldRepaint(_SealedChainPainter oldDelegate) => false;
}

class _NameStep extends StatefulWidget {
  const _NameStep({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  late final AccountApi _api = AccountApi(AppScope.of(context).apiClient);
  final _given = TextEditingController();
  final _family = TextEditingController();
  String? _email;
  String? _givenError;
  String? _familyError;
  String? _failure;
  bool _sending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_email != null) return;
    _api.profile().then((p) {
      if (!mounted) return;
      setState(() {
        _email = p.email;
        if (_given.text.isEmpty) _given.text = p.givenName ?? '';
        if (_family.text.isEmpty) _family.text = p.familyName ?? '';
      });
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _given.dispose();
    _family.dispose();
    super.dispose();
  }

  String? _tooLong(String v) => v.trim().runes.length > AccountApi.maxNameLength
      ? 'Escribe como máximo ${AccountApi.maxNameLength} caracteres.'
      : null;

  Future<void> _save() async {
    setState(() {
      _givenError = _tooLong(_given.text);
      _familyError = _tooLong(_family.text);
      _failure = null;
    });
    if (_givenError != null || _familyError != null) return;
    if (_given.text.trim().isEmpty && _family.text.trim().isEmpty) {
      setState(() => _givenError = 'Escribe al menos tu nombre, o elige «Más tarde».');
      return;
    }
    setState(() => _sending = true);
    try {
      await _api.updateProfile(givenName: _given.text, familyName: _family.text);
      if (mounted) widget.onDone();
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _failure = switch (e) {
          BadRequestException() => 'Revisa los datos: cada campo admite de 1 a ${AccountApi.maxNameLength} caracteres.',
          UnauthorizedException() => null, // la sesión ya se cerró (T-1)
          _ => describeError(e),
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return _Frame(
      step: 1,
      children: [
        Text('¿Cómo te llamamos?', key: const Key('firstSteps.name'), style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Así te saludamos y te identificamos dentro de tu organización. Puedes completarlo ahora o más tarde desde '
          'tu perfil.',
          style: theme.textTheme.bodyLarge?.copyWith(color: muted),
        ),
        if (_failure != null) ...[const SizedBox(height: 12), ErrorMessage(_failure!)],
        const SizedBox(height: 16),
        LabeledField(
          label: 'Nombre',
          child: TextField(
            key: const Key('firstSteps.given'),
            controller: _given,
            enabled: !_sending,
            autofillHints: const [AutofillHints.givenName],
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(errorText: _givenError),
          ),
        ),
        const SizedBox(height: 12),
        LabeledField(
          label: 'Apellido',
          child: TextField(
            key: const Key('firstSteps.family'),
            controller: _family,
            enabled: !_sending,
            autofillHints: const [AutofillHints.familyName],
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(errorText: _familyError),
          ),
        ),
        if (_email != null) ...[
          const SizedBox(height: 12),
          LabeledField(
            label: 'Correo de la cuenta',
            child: TextFormField(key: ValueKey(_email), initialValue: _email, readOnly: true, enabled: false),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_outlined, size: 18, color: muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tu nombre se queda en tu cuenta. No aparece en el recorrido público de las donaciones ni en la '
                'blockchain.',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('firstSteps.later'),
                onPressed: _sending ? null : widget.onDone,
                child: const Text('Más tarde'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('firstSteps.save'),
                onPressed: _sending ? null : _save,
                child: _sending ? BrandDots(color: theme.colorScheme.primary) : const Text('Guardar y continuar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
