# Enmienda 2 de ADR-043 — Navegación del empleado, Cuenta y dependencias nuevas

**Estado:** Aprobado (Adonis, 2026-10-21) · **Fecha:** 2026-10-20 · **Autor:** Adonis · **Revisa:** Carlos
**Origen:** "Funciones de la app móvil y pantallas del empleado" (reunión del 16 de octubre de 2026).

## 1. Qué cambia

| Tema | Funciones | Decisión propuesta |
|---|---|---|
| Bienvenida sin sesión | M-01, M-02 | Pantalla inicial con escanear QR, "tengo un código", qué es PaxFide y botón fijo "Iniciar sesión" (Carlos). |
| Navegación por perfil y gestos | M-03 | Barra inferior según `/me`. Empleado: **Mi día · Escanear (centro) · Pendientes · Cuenta**, con contador de Pendientes. Donante: Inicio · Mis donaciones · Cuenta. Deslizar entre pestañas y "volver" con gesto; acciones al alcance del pulgar. |
| Cuenta | M-26, E-12 | Correo, organización y rol; invitaciones pendientes (`POST /invitations/accept`); cambiar contraseña (cuando exista su contrato, ADR de cuenta y sesiones); cerrar sesión con confirmación que avisa si hay operaciones pendientes. |
| Rutas nuevas (autenticadas) | E-01, E-07, E-08, E-11, E-12 | `/employee/day`, `/operator/pending` (ya existe), `/employee/campaigns`, `/assets/:assetRef/qr`, `/account`. E-02 a E-06 reutilizan `/operator` y `/assets/:assetRef`. |
| Fuera del móvil | E-09, E-10 | Registrar y dividir activos van a la web. |

## 2. Dependencias nuevas (A2/D12)

| Paquete | Versión | Motivo |
|---|---|---|
| `local_auth` | ^3.0.2 | Entrar con huella o rostro (M-28; hecho en la rama de Adonis). |
| `url_launcher` | ^6.3.1 | Abrir el pago en el navegador (M-12) y enlaces de ayuda. |
| `screen_brightness` | ^2.1.1 | Subir el brillo al mostrar el QR a pantalla completa (E-11). |

Sin estas dependencias: M-12 se queda en "copiar el enlace"; E-11 muestra el QR sin cambiar el brillo; M-28 no existe.

## 3. Reglas que no cambian

- Los campos de referencia (`carrierRef`, `receiverRef`, `beneficiaryRef`, `facilityLocation`) nunca piden nombres ni documentos: aviso fijo bajo cada campo.
- Una operación ambigua jamás se reenvía sola: solo "Verificar estado".
- Toda acción de campo: Formulario (E-04) → Revisión (E-05, "Esto queda registrado para siempre") → Resultado (E-06: Confirmado / Guardado en el teléfono / No pudimos confirmarlo).

## 4. Implementación (rama `develop-Vprueba`, 2026-10-21)

| Función | Commit | Cómo quedó |
|---|---|---|
| M-28 | `f27f444` | Huella o rostro, solo en el login, con el logo. Android acepta biometría fuerte y débil (huella y desbloqueo facial); iOS usa Face ID. Necesita `/auth/device-credentials` y `/auth/device-login` en el backend. |
| M-03 | `ea3a827` | Deslizar a los lados cambia de pestaña (Escanear se salta); en la ficha del activo, deslizar a la derecha vuelve; en Pendientes, deslizar hacia abajo actualiza y deslizar una rechazada la descarta con confirmación. |
| M-04 | `06b2225` | Botón «Tamaño del texto» (Normal, Grande, Muy grande) en todas las pantallas y en Cuenta; se suma al del teléfono y se recuerda. |
| E-12, M-26, E-08, E-11 | `f67836c` | Rutas `/account`, `/employee/campaigns` y `/assets/:assetRef/qr`. Cerrar sesión pasa de la barra superior a Cuenta. Mi día se queda en `/operator` (no se crea `/employee/day`). |
| M-12 | `2fc102a` | «Abrir el pago» con `url_launcher`; el enlace sigue visible para copiarlo. |

Límites del contrato actual: `GET /me` no trae el correo ni el nombre de la organización, así que Cuenta muestra el rol y si la cuenta pertenece a una organización. No hay listado de invitaciones pendientes para quien las recibe: se acepta pegando el código del correo.
