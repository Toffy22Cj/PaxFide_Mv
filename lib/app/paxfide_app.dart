import 'package:flutter/material.dart';

import '../shared/theme/pax_theme.dart';
import '../shared/theme/text_size_controller.dart';
import 'app_services.dart';

class PaxFideApp extends StatelessWidget {
  const PaxFideApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: services,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: services.theme,
        builder: (context, mode, _) => MaterialApp.router(
          title: 'PaxFide',
          debugShowCheckedModeBanner: false,
          theme: PaxTheme.light,
          darkTheme: PaxTheme.dark,
          themeMode: mode,
          routerDelegate: services.router,
          // M-04: el tamaño elegido en la app multiplica el del teléfono (con un tope para que nada se rompa).
          builder: (context, child) => ValueListenableBuilder<TextSize>(
            valueListenable: services.textSize,
            builder: (context, size, _) {
              final mq = MediaQuery.of(context);
              final scale = (mq.textScaler.scale(1) * size.factor).clamp(0.5, 3.0);
              return MediaQuery(
                data: mq.copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              );
            },
          ),
          backButtonDispatcher: RootBackButtonDispatcher(),
        ),
      ),
    );
  }
}
