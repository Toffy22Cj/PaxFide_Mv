import 'package:flutter/material.dart';

import '../../features/auth/domain/session_controller.dart';
import '../../features/auth/domain/session_state.dart';
import '../app_routes.dart';
import '../deep_link_parser.dart';
import '../navigation_restore_state.dart';
import '../navigation_store.dart';
import '../pending_intent.dart';
import '../session_guard.dart';

/// Construye el widget de una ruta del árbol.
typedef LocationPageBuilder = Widget Function(BuildContext context, String location);

/// Formulario con cambios sin enviar (§11): si devuelve `false`, el deep link no se consume.
typedef LeaveConfirmation = Future<bool> Function();

/// Router de la app con el `Router` del SDK (sin librerías, ADR-043 §0 A2).
///
/// - G-1 (a): activo desde el arranque. Una ruta cuya fila del guard es "Esperar" muestra la UI de espera, que no
///   es una ruta (no existe `/boot`); las rutas públicas se muestran de inmediato.
/// - El guard ([SessionGuard]) solo recibe la sesión y la categoría de la ruta; este delegado aplica su salida.
///   No lee roles, Outbox ni HTTP.
/// - Logout (manual o T-1): se quitan las rutas autenticadas de la pila (invariante 4).
/// - Restauración (D7): una posición; Decisión B; R4 (un deep link fresco gana).
/// - Deep links (D9): solo entran por [openDeepLink], que recibe lo que produce el único [DeepLinkParser] (R1).
///   Nunca ejecutan comandos (R3).
class AppRouterDelegate extends RouterDelegate<Object> with ChangeNotifier, PopNavigatorRouterDelegateMixin<Object> {
  AppRouterDelegate({
    required this.session,
    required this.navigationStore,
    required this.pendingIntents,
    required this.pageBuilder,
    required this.waitingBuilder,
    this.guard = const SessionGuard(),
  }) {
    _lastStatus = session.state.status;
    session.addListener(_onSessionChanged);
  }

  final SessionController session;
  final NavigationStore navigationStore;
  final PendingIntentHolder pendingIntents;
  final LocationPageBuilder pageBuilder;
  final WidgetBuilder waitingBuilder;
  final SessionGuard guard;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Pila solicitada (rutas del árbol). El guard decide qué se muestra.
  final List<String> _stack = [];
  late SessionStatus _lastStatus;
  bool _restoreDone = false;
  bool _freshIntent = false;
  NavigationRestoreState? _restorable;
  LeaveConfirmation? _leaveConfirmation;

  List<String> get stack => List.unmodifiable(_stack);
  String? get currentLocation => _stack.isEmpty ? null : _stack.last;

  /// Lee la posición persistida. Se llama una vez al arrancar, antes de resolver la sesión.
  ///
  /// Una ruta pública se restaura en el acto: no espera sesión (G-1 a, invariante 2). Una autenticada espera a que
  /// la sesión se resuelva (Decisión B).
  Future<void> loadRestorable() async {
    _restorable = await navigationStore.read();
    final saved = _restorable;
    if (_isResolved(session.state.status) || (saved != null && saved.category == RouteCategory.public)) {
      _applyRestore();
      notifyListeners();
    }
  }

  static bool _isResolved(SessionStatus s) => s == SessionStatus.authenticated || s == SessionStatus.loggedOut;

  // ---------------------------------------------------------------------------------------------------------
  // Sesión
  // ---------------------------------------------------------------------------------------------------------

  void _onSessionChanged() {
    final now = session.state.status;
    final before = _lastStatus;
    _lastStatus = now;
    if (now == before) return;

    if (now == SessionStatus.loggedOut && before == SessionStatus.authenticated) {
      // Invariante 4: logout limpia la pila autenticada. Sin decidir nada sobre el Outbox.
      _stack.removeWhere((l) => AppRoutes.categorize(l) == RouteCategory.authenticated);
    }

    if (now == SessionStatus.authenticated && before == SessionStatus.loggedOut) {
      // Login: destino estándar /home o el PendingIntent (consumo único, R2).
      final intent = pendingIntents.consume();
      _stack
        ..clear()
        ..add(AppRoutes.home);
      if (intent != null && intent.route != AppRoutes.home) _stack.add(intent.route);
    }

    if (_isResolved(now) && !_restoreDone) _applyRestore();
    _normalizeAndNotify();
  }

  void _applyRestore() {
    if (_restoreDone) return;
    _restoreDone = true;
    final saved = _restorable;
    _restorable = null;
    if (saved == null || _freshIntent) return; // R4: el intento fresco gana
    final category = saved.category;
    if (category == RouteCategory.public) {
      _stack
        ..clear()
        ..add(saved.route);
    } else if (category == RouteCategory.authenticated && session.state.status == SessionStatus.authenticated) {
      _stack
        ..clear()
        ..add(AppRoutes.home);
      if (saved.route != AppRoutes.home) _stack.add(saved.route);
    }
    // Autenticada bajo LOGGED_OUT: Decisión B, se descarta (→ /login → /home).
  }

  /// Aplica la salida del guard a la pila (redirigir) y persiste la posición restaurable.
  void _normalizeAndNotify() {
    final status = session.state.status;
    if (_isResolved(status)) {
      final top = currentLocation;
      final decision = top == null
          ? GuardDecision.redirect(status == SessionStatus.authenticated ? AppRoutes.home : AppRoutes.login)
          : guard.evaluate(session: session.state, category: AppRoutes.categorize(top));
      if (decision.type == GuardDecisionType.redirect) {
        if (status == SessionStatus.loggedOut) {
          _stack.removeWhere((l) => AppRoutes.categorize(l) != RouteCategory.public);
        } else {
          _stack.removeWhere((l) {
            final c = AppRoutes.categorize(l);
            return c == RouteCategory.authTransitory || c == RouteCategory.notApproved;
          });
        }
        _stack.add(decision.redirectRoute!);
      }
      // Ruta autenticada con pila vacía debajo → /home (§12, regla 4 de navegación).
      if (status == SessionStatus.authenticated && _stack.first != AppRoutes.home) {
        if (AppRoutes.categorize(_stack.first) == RouteCategory.authenticated) _stack.insert(0, AppRoutes.home);
      }
      _persist();
    }
    notifyListeners();
  }

  void _persist() {
    final top = currentLocation;
    if (top == null) return;
    final params = AppRoutes.paramsOf(top);
    if (params == null) return;
    final state = NavigationRestoreState(
      route: top,
      allowedParams: params,
      schemaVersion: NavigationRestoreState.currentSchemaVersion,
    );
    if (state.isValid()) navigationStore.save(state);
  }

  // ---------------------------------------------------------------------------------------------------------
  // Navegación desde la UI
  // ---------------------------------------------------------------------------------------------------------

  /// Navegación de primer nivel (pestañas): `/home` debajo y el destino encima.
  void go(String location) {
    _stack.clear();
    if (location != AppRoutes.home && AppRoutes.categorize(location) == RouteCategory.authenticated) {
      _stack.add(AppRoutes.home);
    }
    _stack.add(location);
    _normalizeAndNotify();
  }

  void push(String location) {
    if (currentLocation == location) return;
    _stack.add(location);
    _normalizeAndNotify();
  }

  /// Vuelve atrás una posición. Si sale de `/login` o `/register` bajo `LOGGED_OUT`, el login se cancela y la
  /// [PendingIntent] desaparece (R2).
  void back() {
    if (_stack.isEmpty) return;
    final removed = _stack.removeLast();
    _onRemoved(removed);
    if (_stack.isEmpty && session.state.status == SessionStatus.authenticated) _stack.add(AppRoutes.home);
    _normalizeAndNotify();
  }

  void _onRemoved(String location) {
    if (location == AppRoutes.login && session.state.status != SessionStatus.authenticated) {
      pendingIntents.discard();
    }
  }

  /// Un formulario con cambios sin enviar se registra aquí mientras está abierto (§11, opción ii).
  void setLeaveConfirmation(LeaveConfirmation? confirmation) => _leaveConfirmation = confirmation;

  /// Entrada única de deep links (R1). Devuelve `false` si el enlace no se aprobó o no se consumió.
  Future<bool> openDeepLink(ParsedDeepLink link) async {
    if (!link.isApproved) return false;
    final confirm = _leaveConfirmation;
    if (confirm != null && !await confirm()) return false; // cancelar: conserva el formulario, no consume
    _leaveConfirmation = null;
    _freshIntent = true;

    final status = session.state.status;
    if (link.category == RouteCategory.authenticated && status == SessionStatus.loggedOut) {
      pendingIntents.retain(PendingIntent(route: link.route, params: link.parameters));
      _stack
        ..removeWhere((l) => AppRoutes.categorize(l) != RouteCategory.public)
        ..add(AppRoutes.login);
    } else if (link.category == RouteCategory.authenticated && status != SessionStatus.authenticated) {
      // Sesión sin resolver: el destino queda en espera (fila "Esperar").
      _stack
        ..clear()
        ..add(link.route);
    } else {
      if (link.category == RouteCategory.authenticated && _stack.isEmpty) _stack.add(AppRoutes.home);
      if (currentLocation != link.route) _stack.add(link.route);
    }
    _normalizeAndNotify();
    return true;
  }

  // ---------------------------------------------------------------------------------------------------------
  // RouterDelegate
  // ---------------------------------------------------------------------------------------------------------

  @override
  Future<void> setNewRoutePath(Object configuration) async {
    // La plataforma no entrega deep links (sin App Links/Universal Links verificados, S-02): se ignora.
  }

  @override
  Object? get currentConfiguration => null;

  @override
  Widget build(BuildContext context) {
    final pages = <Page<void>>[];
    var waiting = false;
    for (var i = 0; i < _stack.length; i++) {
      final location = _stack[i];
      final d = guard.evaluate(session: session.state, category: AppRoutes.categorize(location));
      if (d.type == GuardDecisionType.allow) {
        pages.add(
          MaterialPage<void>(key: ValueKey('$i:$location'), name: location, child: pageBuilder(context, location)),
        );
      } else if (d.type == GuardDecisionType.wait) {
        waiting = true;
      }
    }
    if (waiting || pages.isEmpty) {
      pages.add(
        MaterialPage<void>(
          key: const ValueKey('waiting'),
          child: Builder(builder: waitingBuilder),
        ),
      );
    }
    return Navigator(
      key: navigatorKey,
      pages: pages,
      onDidRemovePage: (page) {
        final key = page.key;
        if (key is ValueKey<String> && key.value != 'waiting') {
          final index = int.tryParse(key.value.split(':').first);
          if (index != null && index == _stack.length - 1) {
            final removed = _stack.removeLast();
            _onRemoved(removed);
            if (_stack.isEmpty && session.state.status == SessionStatus.authenticated) _stack.add(AppRoutes.home);
            _normalizeAndNotify();
          }
        }
      },
    );
  }

  @override
  void dispose() {
    session.removeListener(_onSessionChanged);
    super.dispose();
  }
}
