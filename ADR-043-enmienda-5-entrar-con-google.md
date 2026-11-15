# Enmienda 5 de ADR-043 — Entrar con Google

**Estado:** Propuesta, implementada en `chore/landing-bienvenida-movil`. **Falta la aprobación de Carlos** para la dependencia `google_sign_in` (A2: «ninguna otra dependencia sin preguntar a Carlos»), antes de fusionar con `develop`. · **Autor:** Adonis

## Por qué

El backend ya tiene «Entrar con Google» y la vinculación de cuentas (ADR-050 D9, `referencia-api-v1`, nota del 2026-10-31). La Enmienda 3 había retirado el botón de Google porque entonces **no existía en el backend**; ya existe.

## Qué cambia

| # | Antes | Ahora |
|---|---|---|
| G1 | Sin Google en el login (Enmienda 3) | «Entrar con Google»: Google da un `idToken` y la app lo envía a `POST /auth/google`. Las reglas son las del login con contraseña: 401 genérico (cuenta no vinculada o `idToken` inválido: se explica que hay que vincularla en Cuenta), `EmailNotVerified`, `AcceptanceRequired` (se aceptan y se repite con el mismo `idToken`) y 503 `GoogleSignInUnavailable` (se ofrece la contraseña). Después, igual que con la contraseña: «Recordarme» y la oferta de biometría |
| G2 | — | En Cuenta → Seguridad: «Vincular mi cuenta de Google» (`POST /account/google/link`, con la contraseña actual) y «Desvincular Google» (`DELETE /account/google/link`). El backend no dice si hay una vinculada, así que se muestran las dos; repetir cualquiera no cambia nada |
| G3 | D12 | Dependencia nueva **`google_sign_in`** (paquete oficial de Flutter). Solo Android e iOS |
| G4 | — | `PAXFIDE_GOOGLE_SERVER_CLIENT_ID` al compilar: el ID de cliente **web** de Google Cloud, el `aud` que acepta el backend (`GOOGLE_OAUTH_CLIENT_IDS`). Sin él, ni el botón ni las opciones de Cuenta aparecen |

## Qué no cambia

- **No hay registro con Google** (ADR-050 D9, Q2 (a)): la cuenta se crea con correo y contraseña y luego se vincula.
- La app **no guarda nada de Google**: ni el `idToken` ni la sesión de Google (se cierra al obtener el `idToken`). Solo el JWT de PaxFide, como siempre (D5).
- Entrar con Google necesita internet, como la primera entrada con contraseña (Enmienda 4, S1).

## Consecuencias

- Android: cada llave que firma el APK necesita su SHA-1 en el cliente Android de Google Cloud (`com.paxfide.mobile` y `com.paxfide.mobile.demo`). Hoy el APK de release se firma con la llave de depuración del PC que compila.
- iOS: falta configurar `GIDClientID` en `Info.plist` y el `bundle id`; hasta entonces, Google solo en Android.
- Tests: `test/flows/google_flow_test.dart` (sin configuración no hay botón; entrar; cancelar; 401; 503; condiciones pendientes con el mismo `idToken`; vincular con la contraseña y sus errores; desvincular sin pasar por Google).
