# Enmienda 4 de ADR-043 — La app funciona sin conexión

**Estado:** Aprobada (Adonis, autor de ADR-043, 2026-11-07, en el chat: «lo que sea, pero apura»). **Revisa:** Carlos. · **Autor:** Adonis

## Por qué

En campo y en zonas sin señal la app tiene que servir igual: entrar, ver lo que ya se cargó, registrar los pasos de los lotes y donar. Hoy no deja ni entrar sin internet. Esta enmienda cambia lo que ADR-043 y ADR-051 decidían en contra, y solo eso.

## Qué cambia

| # | Antes | Ahora |
|---|---|---|
| S1 | El perfil (`GET /me`) solo vivía en memoria; sin red, la app quedaba sin perfil | El perfil de una sesión **recordada** se guarda cifrado (almacén seguro, D5/D12). Al abrir sin red, la app entra con él y lo refresca cuando hay red. Un 401 cierra la sesión como siempre (T-1). La primera entrada en un teléfono sigue necesitando internet: solo el servidor comprueba la contraseña |
| S2 | Sin red, cada pantalla mostraba un error | Las lecturas con JWT o públicas guardan su última respuesta cifrada, por cuenta. Sin red se muestra la guardada con el aviso «Sin conexión: datos guardados». Nunca las del seguimiento por código (el código no se guarda, §0) |
| S3 | D6 y DDM-20: nada se enviaba sin una acción del empleado | La cola se **envía sola** cuando hay red (al abrir la app, al volver a ella y cada 30 s mientras haya pendientes), con el **mismo `Command-Id`**: el backend devuelve la misma respuesta a un reenvío y nunca duplica (referencia-api-v1 §0). Se envían `PENDING` y `AMBIGUOUS`; `FAILED` sigue esperando a la persona. Siguen «Enviar» y «Verificar estado» a mano |
| S4 | ADR-051 F5: entregar exigía subir la foto con conexión y la foto nunca quedaba en el teléfono | Sin red, la entrega se guarda en la cola **con su foto cifrada** en el almacén seguro. Al enviarla, primero se sube la foto y luego la entrega con su `evidenceRef`; la foto se borra del teléfono al subirse. Riesgo aceptado: mientras no se envía, la foto (que puede mostrar personas) está cifrada en el teléfono |
| S5 | Donar necesitaba conexión; el `statusToken` solo vivía en memoria | Sin red, la donación se guarda en la cola y se envía sola con su `Command-Id`. El resultado (`intentId`, `statusToken` y el enlace de pago) se guarda **cifrado**, para pagar y consultar el estado después desde «Mis donaciones pendientes de pago». El pago sigue necesitando internet (la pasarela) |

## Qué no cambia

- El almacenamiento sigue siendo `flutter_secure_storage` (D5/D12): sin dependencias nuevas.
- El seguimiento por código, cambiar la contraseña, desactivar la cuenta, la integridad y el relato siguen necesitando red.
- H2: cada entrada de la cola y cada lectura guardada es de la cuenta que la creó; otra cuenta no la ve ni la envía.

## Consecuencias

- Puede haber datos viejos a la vista: se marcan siempre.
- Un comando rechazado por el servidor al enviarse solo queda `FAILED` en Pendientes, como antes.
- Tests: perfil guardado y entrada sin red; lectura guardada con su aviso y por cuenta; envío automático sin duplicar (mismo `Command-Id`) y sin tocar `FAILED`; entrega en cola con su foto, subida antes de entregar y borrada después; donación en cola, enviada sola y con el pago después.
