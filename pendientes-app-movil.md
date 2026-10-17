# Funciones pendientes de la app móvil (`paxfide_mobile`)

**Fecha:** 2026-10-17 · **Rama de referencia:** `claude/focused-goodall-meb6sh` (app y backend)
**Alcance de la app** (ADR-043 §0, A3): donante y operador de campo, más la Predicción para `ADMINISTRATOR`/`REPRESENTATIVE`. Lo administrativo (crear causas, miembros, verificar organizaciones) es de la web (ADR-046).

**Cómo se hizo:** se compararon las 57 rutas del backend con las que usa la app, y se revisaron los pendientes del ADR-043 y de `front-fase1.md`. Cada punto dice en qué se basa.

**Dónde hay que tocar:** *Solo app*, *Backend y app*, o *Decisión* (hay que decidir antes de construir).

**Estado:** ⬜ pendiente · 🟨 en curso · ✅ hecho · ⏸️ en pausa

---

## Visual

| # | Función | Por qué falta (evidencia) | Dónde | Estado |
|---|---|---|---|---|
| 1 | Ícono de la app y pantalla de arranque con el logo de PaxFide | El ícono de Android es idéntico al de la plantilla de Flutter (misma huella de archivo). El logo ya existe en `assets/images/paxfide_logo.png` y no se usa ahí | Solo app | ⬜ |
| 2 | Login y recuadro de la huella en modo oscuro | `login_screen.dart` tiene 29 colores claros escritos a mano y `biometric_login_dialog.dart` 6; no usan `PaxPalette`, así que salen blancos aunque la app esté en oscuro | Solo app | ⬜ |
| 3 | Recordar el modo claro u oscuro, y opción "como el teléfono" | `AppServices.darkMode` es un `ValueNotifier(true)` en memoria: al reabrir, la app vuelve siempre a oscuro | Solo app | ⬜ |
| 4 | Imagen o portada de cada causa | Las causas son solo texto; la causa no tiene campo de imagen en el backend | Backend y app | ⬜ |
| 5 | Cargas con esqueletos y transiciones suaves | Las cargas son un círculo girando; no hay animaciones propias | Solo app | ⬜ |
| 6 | Accesibilidad: etiquetas para lectores de pantalla y texto grande | Solo un archivo usa `Semantics`. Faltan en botones de solo ícono (QR, tema, cerrar sesión) y en los gráficos | Solo app | ⬜ |
| 7 | Identificador propio de la app | Sigue siendo `com.example.paxfide_mobile` (Android). Hay que cambiarlo antes de compartir el APK fuera del equipo o publicar | Solo app | ⬜ |

## De uso

| # | Función | Por qué falta (evidencia) | Dónde | Estado |
|---|---|---|---|---|
| 8 | Deslizar hacia abajo para actualizar (causas, mis donaciones, operaciones) | Ninguna lista usa `RefreshIndicator` | Solo app | ⬜ |
| 9 | Ver el seguimiento desde "Mis donaciones" | El código de seguimiento solo se ve una vez, al confirmarse el pago. `GET /account/donations` lo envía, pero la app lo descarta (DDM-25). Si el donante no lo copió, no puede ver a dónde llegó su ayuda | Solo app (revisar DDM-25) | ⬜ |
| 10 | Abrir el pago con un botón | Hoy se muestra el enlace del checkout como texto para copiarlo (`donate_sheet.dart`); en la demo se paga con `scripts/pruebas/pagar.sh` | Solo app + dependencia `url_launcher` (aprobación A2/D12); un pago real necesita backend | ⬜ |
| 11 | Recuperar y cambiar la contraseña | No existe ruta en el backend ni pantalla en la app. Cambiar la contraseña también es lo que anula la huella en todos los teléfonos (ADR-043 §8.8) | Backend (correo con Mailpit/Gmail, ya configurado) y app | ⬜ |
| 12 | Avisar antes de que venza la sesión, o renovarla | El JWT dura 8 h (`JWT_TTL`) y no hay renovación: un operador puede quedar fuera en mitad de una entrega. La huella lo alivia | Backend y app | ⬜ |
| 13 | Aceptar la invitación de empleado en la app | Los empleados usan la app, pero la invitación llega por correo con enlace a la web. `POST /invitations/accept` ya existe | Solo app | ⬜ |
| 14 | El operador ve sus causas asignadas | `GET /me/campaigns` existe, pero la app solo lo usa en Predicción | Solo app | ⬜ |
| 15 | Buscar y filtrar causas (nombre, organización, por terminar) | `GET /public/campaigns` solo pagina, sin búsqueda | Backend y app | ⬜ |
| 16 | Perfil: ver el correo, cerrar sesión y pedir la eliminación de la cuenta (Ley 1581 de datos personales) | No hay pantalla de perfil; `GET /me` no devuelve el correo | Backend y app | ⬜ |
| 17 | Notificaciones: pago confirmado, donación entregada | No existen | Backend y app + dependencia nueva (p. ej. Firebase) | ⬜ |
| 18 | Certificado de donación descargable | No existe | Backend y app | ⬜ |
| 19 | Volver a donde estaba al reabrir la app | D7 del ADR-043, anotada como no implementada en §8.4 | Solo app | ⬜ |
| 20 | Registrar el activo de una donación y dividirlo (`from-donation`, `split`) | El backend los tiene y el *golden path* los pone en el empleado, pero el ADR-043 no decidió si van en la app o en la web (N2) | Decisión, luego app | ⬜ |

## Pendientes que ya teníamos

| # | Función | Referencia | Estado |
|---|---|---|---|
| 21 | Probar la entrada con huella en un teléfono real | ADR-043 §8.8 (en pausa: el computador se quedó sin memoria al crear el APK; Gradle ya se bajó a 2 GB) | ⏸️ |
| 22 | Gráfico de donaciones en el detalle de la causa, solo para el administrador y el representante dueños | ADR-043 §8.7 (necesita que el backend relacione el `publicCode` con la organización para un miembro) | ⬜ |

---

## Orden sugerido

1. **Solo app y rápidos:** 2 y 3 (login en oscuro y recordar el tema), 1 (ícono), 8 (deslizar para actualizar), 9 (seguimiento desde mis donaciones).
2. **Con backend:** 11 (contraseña), luego 13 y 14 para el operador.
3. **Con decisión o dependencia nueva:** 10, 17 y 20.

Cada función que se haga se registra también en el ADR-043 y se marca aquí con su estado.
