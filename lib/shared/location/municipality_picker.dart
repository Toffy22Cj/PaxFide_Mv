import 'package:flutter/material.dart';

import '../../core/errors/app_exceptions.dart';
import '../error_messages.dart';
import '../motion/pax_route.dart';
import '../widgets/pax_app_bar.dart';
import '../widgets/state_views.dart';
import 'location_catalog.dart';

/// Elegir el municipio DIVIPOLA de un paso (enmienda 2 de ADR-029): se escribe parte del nombre y se toca. Devuelve el
/// municipio, o null si se cierra sin elegir.
Future<Municipality?> pickMunicipality(BuildContext context, LocationCatalogApi catalog) => Navigator.of(context)
    .push<Municipality>(PaxPageRoute(fullscreenDialog: true, builder: (_) => _MunicipalityPicker(catalog: catalog)));

/// Minúsculas y sin tildes, para que «bogota» encuentre «BOGOTÁ, D.C.».
String _fold(String s) {
  const from = 'áéíóúüñ';
  const to = 'aeiouun';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString();
}

class _MunicipalityPicker extends StatefulWidget {
  const _MunicipalityPicker({required this.catalog});
  final LocationCatalogApi catalog;

  @override
  State<_MunicipalityPicker> createState() => _MunicipalityPickerState();
}

class _MunicipalityPickerState extends State<_MunicipalityPicker> {
  final _query = TextEditingController();
  List<Municipality>? _all;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final all = await widget.catalog.municipalities();
      if (mounted) setState(() => _all = all);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final q = _fold(_query.text.trim());
    final shown = all == null || q.isEmpty ? all : all.where((m) => _fold(m.zoneName).contains(q)).toList();
    return Scaffold(
      appBar: PaxAppBar(title: const Text('Municipio del paso')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                key: const Key('municipality.search'),
                controller: _query,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Escribe el municipio o el departamento',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: switch ((all, _error)) {
                (null, final e?) => ErrorRetryView(
                  message: e is AppException ? describeError(e) : 'No pudimos cargar los municipios.',
                  onRetry: _load,
                ),
                (null, _) => const LoadingView(label: 'Cargando municipios…'),
                _ when shown!.isEmpty => const MessageView(icon: Icons.search_off, title: 'Ningún municipio coincide.'),
                _ => ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final m = shown[i];
                    return ListTile(
                      key: Key('municipality.${m.code}'),
                      title: Text(m.zoneName),
                      onTap: () => Navigator.of(context).pop(m),
                    );
                  },
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}
