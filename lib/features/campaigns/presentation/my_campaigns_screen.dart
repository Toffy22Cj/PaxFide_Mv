import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/app_shell.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/quantity.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/domain/session_controller.dart';
import '../../physical_assets/data/physical_asset_api.dart';
import '../../physical_assets/presentation/asset_screen.dart';
import '../../prediction/data/prediction_api.dart';
import 'campaign_public_screen.dart';

/// `/employee/campaigns` (E-08): las convocatorias asignadas (`GET /me/campaigns`) y, dentro de cada una, sus activos
/// por estado (los de la organización con ese `campaignRef`). Tocar un activo abre su ficha.
class MyCampaignsScreen extends StatefulWidget {
  const MyCampaignsScreen({super.key});

  @override
  State<MyCampaignsScreen> createState() => _MyCampaignsScreenState();
}

class _MyCampaignsScreenState extends State<MyCampaignsScreen> {
  late final AppServices _services = AppScope.of(context);
  List<CampaignChoice>? _campaigns;
  List<PhysicalAssetDto>? _assets;
  Object? _error;
  String? _organizationId;

  Future<void> _load(String organizationId) async {
    _organizationId = organizationId;
    setState(() {
      _error = null;
      _campaigns = null;
    });
    try {
      final results = await Future.wait([
        PredictionApi(_services.apiClient).myCampaigns(),
        PhysicalAssetApi(_services.apiClient).listForOrganization(organizationId),
      ]);
      if (!mounted) return;
      setState(() {
        _campaigns = results[0] as List<CampaignChoice>;
        _assets = results[1] as List<PhysicalAssetDto>;
      });
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      location: AppRoutes.myCampaigns,
      title: 'Mis convocatorias',
      body: ListenableBuilder(
        listenable: _services.session,
        builder: (context, _) {
          final p = _services.session.principal;
          if (p == null) {
            return _services.session.profileStatus == ProfileStatus.unavailable
                ? ErrorRetryView(message: 'No pudimos cargar tu perfil.', onRetry: _services.session.reloadProfile)
                : const LoadingView();
          }
          final org = p.organizationId;
          if (!p.showsOperatorActions || org == null) {
            return const MessageView(icon: Icons.lock_outline, title: 'Tu cuenta no tiene acceso operativo.');
          }
          if (_organizationId != org) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _load(org));
            return const LoadingView();
          }
          final e = _error;
          if (e != null) {
            if (e is TransportException) {
              return ErrorRetryView(
                message: 'Sin conexión. Las convocatorias se ven cuando vuelvas a tener señal.',
                onRetry: () => _load(org),
              );
            }
            return ErrorRetryView(message: describeError(e), onRetry: () => _load(org));
          }
          final campaigns = _campaigns;
          if (campaigns == null) return const LoadingView();
          if (campaigns.isEmpty) {
            return const MessageView(
              icon: Icons.campaign_outlined,
              title: 'No tienes convocatorias asignadas.',
              detail: 'Quien administra tu organización te las asigna desde la web.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => _load(org),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [for (final c in campaigns) _campaignCard(context, c)],
            ),
          );
        },
      ),
    );
  }

  Widget _campaignCard(BuildContext context, CampaignChoice c) {
    final assets = (_assets ?? const <PhysicalAssetDto>[]).where((a) => a.campaignRef == c.campaignRef).toList();
    final groups = <String, List<PhysicalAssetDto>>{};
    for (final a in assets) {
      groups.putIfAbsent(lifecycleLabel(a.lifecycleStatus), () => []).add(a);
    }
    return Card(
      key: Key('mycampaigns.${c.campaignRef}'),
      child: ExpansionTile(
        leading: const Icon(Icons.campaign_outlined),
        title: Text(c.title),
        subtitle: Text(
          '${campaignStatusLabel(c.status)} · ${assets.length} ${assets.length == 1 ? 'activo' : 'activos'}',
        ),
        children: [
          if (assets.isEmpty) const ListTile(dense: true, title: Text('Esta convocatoria todavía no tiene activos.')),
          for (final g in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${g.key} (${g.value.length})', style: Theme.of(context).textTheme.titleSmall),
              ),
            ),
            for (final a in g.value)
              ListTile(
                key: Key('mycampaigns.asset.${a.assetRef}'),
                title: Text(a.assetRef),
                subtitle: Text(formatQuantityWithUnit(a.quantity, a.unitOfMeasure)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _services.router.push(AppRoutes.assetPath(a.assetRef)),
              ),
          ],
        ],
      ),
    );
  }
}
