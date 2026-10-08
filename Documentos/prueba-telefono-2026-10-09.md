# Prueba en teléfono — guía para mañana (2026-10-09)

**Para quién:** la persona que haga la prueba en un Android real. Preparado la noche del 2026-10-08.
**Qué ya está probado sin teléfono:** la app de escritorio (Linux, mismo código Dart) contra el backend real local
(`develop` `85b702b`), con capturas en `evidencia-mobile/escritorio-2026-10-08/`, y el recorrido automático contra
el backend real (`evidencia-mobile/recorrido-backend-real-*`).
**Qué NO se ha podido hacer:** compilar el APK. El entorno donde se preparó no podía descargar el SDK de Android
(`dl.google.com` bloqueado por su red). La primera compilación es parte de la prueba.

## 1. Preparar

1. Backend: `runbook-demo-local.md` (pasos 1–5). Esperar a ver `Demo seed: platform account` en el log antes del
   paso 5 (el backend responde unos segundos antes de que la semilla termine; S-10).
2. Túnel (recomendado): `cloudflared tunnel --url http://localhost:8080` → `https://<algo>.trycloudflare.com`.
3. `cp config/movil.example.json config/movil.json` y poner `PAXFIDE_API_BASE_URL=https://<algo>.trycloudflare.com/api/v1`.
   `PAXFIDE_PUBLIC_BASE_URL`: el origen de la web (otro túnel a `:3000`) o, si no hay web, cualquier origen fijo
   para que los QR sean coherentes con el escáner.
4. Teléfono con depuración USB; `flutter devices` lo lista.
5. `flutter run --flavor normal --dart-define-from-file=config/movil.json`.
   Si falla la compilación de Gradle, anotar el error literal: lo más probable es `android/app/build.gradle.kts`
   (sabores y `network_security_config` generado, DDM-41).

Alternativa sin túnel (misma Wi-Fi): `--flavor demo` con `http://<IP-del-ordenador>:8080/api/v1`. Solo ese host
puede ir por HTTP sin cifrar.

## 2. Lista de comprobación

| # | Qué | Cuenta | Esperado |
|---|---|---|---|
| 1 | Login con espacios antes/después del email | `administrador@demo.paxfide.local` | Entra; inicio con Mis donaciones, Operaciones y Predicción |
| 2 | Cerrar la app y abrirla | — | Sigue la sesión (token en el almacén cifrado de Android) |
| 3 | Predicción → elegir del listado | administrador | Etiqueta "ESTIMACIÓN…"; si la convocatoria es nueva, solo el motivo "Fuera del rango del modelo…", sin cifra |
| 4 | **Escanear con la cámara** el QR de un activo (generarlo en otra pantalla con "Mostrar QR") | empleado | Abre el activo; "Recibir"/"Entregar" según el estado |
| 5 | Despachar un activo `REGISTERED`; luego **modo avión** y "Recibir" | empleado | Con avión: queda "Pendiente de enviar"; al volver la red, "Enviar" en Operaciones pendientes |
| 6 | Cortar la red **durante** el envío (o cerrar la app) | empleado | "No pudimos confirmar la operación" → "Verificar estado" → confirmada |
| 7 | Escanear el QR de una convocatoria con la cámara | sin sesión | Convocatoria con importes en `… COP` con 2 decimales |
| 8 | Donar 1000 en la convocatoria | donante | "Se donarán 1 000,00 COP."; URL del checkout simulado |
| 9 | Seguimiento: escribir el código | sin sesión | Hechos, logística, "Verificación de integridad: No disponible" |
| 10 | Logout con operaciones pendientes y entrar con otra cuenta | empleado → donante | La otra cuenta no las ve; al volver el empleado, reaparecen |

Para cada fila: OK / fallo con captura y hora.

## 3. Lo que solo se puede ver en el teléfono

Cámara y permisos; almacenamiento cifrado de Android tras reiniciar; modo avión y cortes reales; tamaño de
pantalla de móvil (barra inferior en lugar del carril lateral); el teclado numérico del importe.
