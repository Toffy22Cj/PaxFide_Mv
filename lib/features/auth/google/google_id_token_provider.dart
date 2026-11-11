import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// Resultado de pedirle a Google un `idToken` (ADR-050 D9).
sealed class GoogleIdTokenResult {
  const GoogleIdTokenResult();
}

class GoogleIdTokenObtained extends GoogleIdTokenResult {
  const GoogleIdTokenObtained(this.idToken);
  final String idToken;
}

/// La persona cerró la ventana de Google: no se dice nada.
class GoogleIdTokenCanceled extends GoogleIdTokenResult {
  const GoogleIdTokenCanceled();
}

/// Google no está disponible o mal configurado en este teléfono (sin servicios de Google, ID de cliente o SHA-1).
class GoogleIdTokenFailed extends GoogleIdTokenResult {
  const GoogleIdTokenFailed();
}

/// Pide a Google el `idToken` de una cuenta, que valida el backend. Solo eso: la app no guarda nada de Google.
abstract class GoogleIdTokenProvider {
  /// Hay que mostrar «Entrar con Google»: plataforma compatible y app configurada.
  bool get isAvailable;

  Future<GoogleIdTokenResult> obtain();
}

/// `google_sign_in` (Android e iOS), con el ID de cliente **web** como `serverClientId`: es el `aud` del `idToken`
/// que el backend acepta (`GOOGLE_OAUTH_CLIENT_IDS`).
class GoogleSignInIdTokenProvider implements GoogleIdTokenProvider {
  GoogleSignInIdTokenProvider(this.serverClientId);

  final String serverClientId;
  Future<void>? _init;

  static bool get supportedPlatform => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  bool get isAvailable => supportedPlatform;

  @override
  Future<GoogleIdTokenResult> obtain() async {
    try {
      await (_init ??= GoogleSignIn.instance.initialize(serverClientId: serverClientId));
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      // No se mantiene la sesión de Google en la app: solo hacía falta el idToken.
      await GoogleSignIn.instance.signOut();
      return idToken == null || idToken.isEmpty ? const GoogleIdTokenFailed() : GoogleIdTokenObtained(idToken);
    } on GoogleSignInException catch (e) {
      _init = e.code == GoogleSignInExceptionCode.clientConfigurationError ? null : _init;
      return switch (e.code) {
        GoogleSignInExceptionCode.canceled || GoogleSignInExceptionCode.interrupted => const GoogleIdTokenCanceled(),
        _ => const GoogleIdTokenFailed(),
      };
    } on Object {
      _init = null;
      return const GoogleIdTokenFailed();
    }
  }
}

/// Sin Google (sin ID de cliente configurado, Linux o web): el botón no aparece.
class UnavailableGoogleIdTokenProvider implements GoogleIdTokenProvider {
  const UnavailableGoogleIdTokenProvider();

  @override
  bool get isAvailable => false;

  @override
  Future<GoogleIdTokenResult> obtain() async => const GoogleIdTokenFailed();
}
