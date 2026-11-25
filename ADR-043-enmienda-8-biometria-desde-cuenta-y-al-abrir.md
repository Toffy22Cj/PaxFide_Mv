# ADR-043 — Enmienda 8: activar la biometría desde Cuenta y pedirla al abrir la app

**Estado:** **PROPUESTA — espera la aprobación de Adonis** (dueño del móvil). Redactada el 2026-11-20 por el agente, a petición de Manuel («en la app móvil no hay una opción para iniciar con la biometría … hazla»; respuesta del mismo día: «pedir la huella al abrir la app» y «activar/desactivar desde Cuenta»). **No autoriza código por sí sola:** el PR de código no se fusiona antes de que esta enmienda esté aprobada (regla 3.5).

## Qué hay hoy (verificado sobre `develop` `0e7f712`)

La entrada con huella o rostro (M-28, Enmienda 2) existe, pero solo se ofrece en dos momentos:
1. un diálogo **único** justo después de entrar con contraseña (`login_screen.dart`, `_askToEnableBiometric`): si se responde «Ahora no» o el alta falla, no hay otra forma de activarla;
2. el botón «Entrar con huella o rostro» en la pantalla de Entrar (`login-biometric`), que solo se ve si la app abre en esa pantalla.

Con «Recordarme» (marcado por defecto) la app restaura la sesión y abre directo en Inicio: **la pantalla de Entrar, y con ella la biometría, no aparece nunca**. Cuenta solo permite cambiar la contraseña, vincular Google y desactivar la cuenta.

## Decisión propuesta

| # | Cambio |
|---|---|
| E8-1 | **Cuenta → Seguridad:** un interruptor **«Entrar con huella o rostro»**, visible si el teléfono tiene biometría configurada o ya estaba activada aquí. Encenderlo **confirma con la huella o el rostro** y da de alta este teléfono (`POST /auth/device-credentials`, el mismo que el diálogo de después de la contraseña). Apagarlo borra la credencial **solo de este teléfono** (como «No usar la biometría» del login). |
| E8-2 | **Cuenta → Seguridad:** un interruptor **«Pedir la huella al abrir la app»**, visible solo con la biometría activada aquí. **Se enciende solo** al activar la entrada desde Cuenta y se puede apagar aparte. Sin valor guardado está **apagado**: quien activó la biometría con el diálogo anterior no ve ningún cambio. |
| E8-3 | **Al abrir la app con la sesión recordada** y con E8-2 encendido, la app queda **tapada** hasta que la huella o el rostro sean correctos (`BiometricLockGate`). Se decide **una sola vez**, cuando la sesión se resuelve al arrancar: una sesión iniciada después (contraseña, Google o biometría en el login) no la pide. Mientras se decide, la app también está tapada (Inicio no se ve ni un instante). |
| E8-4 | **Si falla o se cancela:** sigue bloqueada, con el motivo y dos salidas: «Usar huella o rostro» (reintenta) y «Entrar con contraseña», que **cierra la sesión** (sin tocar lo guardado sin conexión, H2) y deja el login. |
| E8-5 | **No cambia el backend ni ningún contrato.** Sin dependencias nuevas (`local_auth` y `flutter_secure_storage` ya están aprobados). La preferencia se guarda en `flutter_secure_storage` (clave `paxfide.biometric.lock`), como la credencial. La huella nunca sale del teléfono y el desbloqueo **no llama al backend**: la sesión ya está iniciada. |

## Qué no cambia
- El login con huella (M-28), sus reglas (`AcceptanceRequired`, `EmailNotVerified`) y el diálogo de después de la contraseña.
- El JWT, su vida y su revocación: **abrir la app con la huella no renueva ni valida el JWT**; si expiró o se revocó, el primer pedido da 401 y la sesión se cierra como siempre (T-1).
- La credencial del dispositivo: al cambiar la contraseña el backend la anula (ADR-050); el interruptor de Cuenta queda encendido en el teléfono hasta el próximo intento (el login lo detecta y la borra, como hoy).

## Qué NO hace (a propósito)
- **No bloquea al volver del segundo plano** (solo al abrir la app en frío). Pedirlo tras un tiempo en segundo plano es otra decisión (Q-8-1).
- **No impide ver lo que ya esté en pantalla** mientras el teléfono está desbloqueado y la app abierta.

## Preguntas (con recomendación)
- **Q-8-1 — ¿Pedir también al volver del segundo plano?** Recomiendo **no** en este corte: más fricción en el trabajo de campo con guantes y poca luz. Se puede añadir con un tiempo configurable.
- **Q-8-2 — ¿Encender «al abrir» al activar desde Cuenta?** Recomiendo **sí** (es lo que el usuario espera de «iniciar con biometría»), con interruptor para apagarlo.
- **Q-8-3 — ¿Mostrar el interruptor de «al abrir» a quien activó la biometría con el diálogo anterior?** Recomiendo **sí**, apagado por defecto.

## Definición de hecho
Las pruebas de `test/features/auth/biometric_lock_test.dart` (tres grupos: `BiometricLogin`, abrir la app, Cuenta) con el rojo previo visible, incluidas las negativas (sin credencial, sin preferencia, sin sesión guardada, cancelar la huella, sin biometría en el teléfono); `flutter analyze` y `flutter test` completos con su salida literal. **Hay que ejecutarlas en un entorno con Flutter:** el que escribió este cambio no lo tiene y **no las ha ejecutado**.
