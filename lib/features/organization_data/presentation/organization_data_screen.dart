import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/app_shell.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/domain/principal.dart';
import '../../auth/domain/session_controller.dart';
import '../data/organization_data_api.dart';
import 'organization_data_charts.dart';

/// `/organization-data`: la segunda excepción de alcance de A3 (Enmienda 6 de ADR-043). Dos paneles de solo lectura,
/// «Fondos por mes» y «Actividad», según `/me` y con las reglas del backend; el donante no la ve. Un 403 y la falta de
/// conexión tienen su propio estado: nunca un gráfico vacío presentado como «sin datos».
class OrganizationDataScreen extends StatelessWidget {
  const OrganizationDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return AppShell(
      location: AppRoutes.organizationData,
      title: 'Datos de la organización',
      body: ListenableBuilder(
        listenable: services.session,
        builder: (context, _) {
          final p = services.session.principal;
          if (p == null) {
            return services.session.profileStatus == ProfileStatus.unavailable
                ? ErrorRetryView(message: 'No pudimos cargar tu perfil.', onRetry: services.session.reloadProfile)
                : const LoadingView();
          }
          if (!p.showsOrganizationData) {
            return const MessageView(
              key: Key('orgdata.denied'),
              icon: Icons.lock_outline,
              title: 'Tu cuenta no tiene acceso a los datos de la organización.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (p.showsFundsData) ...[
                _PanelTitle('Fondos por mes', key: const Key('orgdata.funds.title')),
                _LoadedPanel<MonthlyFunds>(
                  // por cuenta: al cambiar de cuenta no se arrastra la lectura de la anterior
                  key: ValueKey('funds-${p.accountId}'),
                  prefix: 'orgdata.funds',
                  load: (api, org) => api.fundsMonthly(org),
                  principal: p,
                  builder: (context, funds) =>
                      FundsChartsPanel(funds: funds, principal: p, store: services.chartPreferences),
                ),
                const SizedBox(height: 24),
              ],
              if (p.showsActivityData) ...[
                _PanelTitle('Actividad', key: const Key('orgdata.activity.title')),
                _LoadedPanel<OrganizationActivity>(
                  key: ValueKey('activity-${p.accountId}'),
                  prefix: 'orgdata.activity',
                  load: (api, org) => api.activity(org),
                  principal: p,
                  builder: (context, activity) =>
                      ActivityChartsPanel(activity: activity, principal: p, store: services.chartPreferences),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
  );
}

/// Un panel con su lectura: cargando, 403, error con reintento, o los gráficos (con el aviso si salen de lo guardado).
class _LoadedPanel<T> extends StatefulWidget {
  const _LoadedPanel({
    super.key,
    required this.prefix,
    required this.load,
    required this.principal,
    required this.builder,
  });
  final String prefix;
  final Future<Loaded<T>> Function(OrganizationDataApi api, String organizationId) load;
  final Principal principal;
  final Widget Function(BuildContext context, T value) builder;

  @override
  State<_LoadedPanel<T>> createState() => _LoadedPanelState<T>();
}

enum _Phase { loading, ready, forbidden, failed }

class _LoadedPanelState<T> extends State<_LoadedPanel<T>> {
  late final AppServices _services = AppScope.of(context);
  _Phase _phase = _Phase.loading;
  Loaded<T>? _loaded;
  Object? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });
    try {
      final loaded = await widget.load(OrganizationDataApi(_services.apiClient), widget.principal.organizationId!);
      if (!mounted) return;
      setState(() {
        _loaded = loaded;
        _phase = _Phase.ready;
      });
    } on ForbiddenException {
      if (mounted) setState(() => _phase = _Phase.forbidden);
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _phase = _Phase.failed;
        });
      }
    }
  }

  static String _date(DateTime at) {
    final l = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prefix;
    switch (_phase) {
      case _Phase.loading:
        return LoadingView(key: Key('$p.loading'));
      case _Phase.forbidden:
        return MessageView(
          key: Key('$p.forbidden'),
          icon: Icons.lock_outline,
          title: 'No tienes permiso para ver estos datos.',
          detail: 'Si crees que es un error, pide a quien administra tu organización que revise tu rol.',
        );
      case _Phase.failed:
        return ErrorRetryView(key: Key('$p.error'), message: describeError(_error!), onRetry: _fetch);
      case _Phase.ready:
        final loaded = _loaded as Loaded<T>;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (loaded.fromCache)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  key: Key('$p.offline'),
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loaded.cachedAt == null
                            ? 'Sin conexión: se muestra la última respuesta guardada (no sabemos de qué fecha).'
                            : 'Sin conexión: se muestra la última respuesta guardada el ${_date(loaded.cachedAt!)}.',
                      ),
                    ),
                  ],
                ),
              ),
            widget.builder(context, loaded.value),
          ],
        );
    }
  }
}
