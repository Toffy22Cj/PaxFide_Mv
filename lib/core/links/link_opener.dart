import 'package:url_launcher/url_launcher.dart';

/// Abrir un enlace fuera de la app (M-12: el pago en el navegador). Devuelve false si el teléfono no pudo abrirlo.
abstract interface class LinkOpener {
  Future<bool> open(Uri url);
}

class UrlLauncherLinkOpener implements LinkOpener {
  const UrlLauncherLinkOpener();

  @override
  Future<bool> open(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}
