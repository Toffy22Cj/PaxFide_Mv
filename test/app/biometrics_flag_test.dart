import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_config.dart';
import 'package:paxfide_mobile/app/bootstrap.dart';

import '../support/fakes.dart';

void main() {
  test('S-01: sin PAXFIDE_BIOMETRICS la biometría no se ofrece', () async {
    expect(biometricsEnabled, isFalse);
    final services = buildServices(
      config: AppConfig(apiBaseUrl: Uri.parse('https://api.test/api/v1'), publicOrigin: null),
      secureStore: InMemorySecureKeyValueStore(),
    );
    expect(await services.biometricLogin.isAvailable(), isFalse);
    expect(await services.biometricLogin.canOffer(), isFalse);
  });
}
