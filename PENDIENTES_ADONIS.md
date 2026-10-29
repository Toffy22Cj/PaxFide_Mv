# Pendientes de Adonis (app móvil)

Rama `chore/landing-bienvenida-movil`, al día 2026-10-29. `flutter analyze` limpio y la suite completa en verde (evidencia en `Documentos/evidencia-mobile/`).

Hechas: todas las funciones de la lista del 16 de octubre a nombre de Adonis que no dependen de un ADR sin aprobar o de un contrato que no existe. El detalle está en la §6 y la §7 de la Enmienda 2 de ADR-043. Lo último (2026-10-28): términos y condiciones, recuperar y cambiar la contraseña, correo y nombre en Cuenta, desactivar la cuenta, Mi impacto, entregar con foto, integridad visible con sello y huella por paso, y el tipo del activo en la ficha. El 2026-10-29: la app sigue a la web en Inicio (con la ciudad), la tarjeta de convocatoria, el seguimiento, los primeros pasos, Mis donaciones, las cargas y las transiciones (§8 de la Enmienda 2).

## Bloqueadas por un ADR sin aprobar

| ID | Falta | Archivo | Siguiente paso exacto |
|---|---|---|---|
| M25 | Aprobar `ADR-050-mapa-del-recorrido.md` | `lib/features/tracking/presentation/tracking_screen.dart` (`RouteTimeline`) | Añadir `flutter_map` + OSM bajo la línea de tiempo, con coordenadas del catálogo de lugares (sin GPS del empleado). Backend de M25 solo tras el ADR. |

## Hechas en la app, esperando backend

| ID | Interfaz | Archivo | Siguiente paso exacto |
|---|---|---|---|
| M10 | `CampaignSearch` (`PublicCampaignSearch`) | `lib/features/campaigns/domain/public_campaign_search.dart`, `presentation/campaign_search_view.dart` | Ya funciona buscando en el teléfono sobre `GET /public/campaigns` (hasta 5 páginas). Cuando la enmienda de ADR-041 traiga búsqueda en el backend, implementar otra `CampaignSearch` con ese contrato. |
| M22 | `ReceiptSource` y `ReceiptSharer` | `lib/features/donations/domain/receipt.dart`, `presentation/receipt_view.dart` | Endpoint del comprobante (Manuel) e implementar `ReceiptSource`; para compartir, aprobar una dependencia (p. ej. `share_plus`) e implementar `ReceiptSharer`. |
| M28 | Biometría (visible, decisión del 2026-10-28) | `lib/features/auth/biometrics/` | El backend que se use debe tener `/auth/device-credentials` y `/auth/device-login`. Hoy solo están en la rama `claude/focused-goodall-meb6sh` del backend, no en `develop`. |
| E-12 | Invitaciones pendientes en Cuenta | `lib/features/account/presentation/account_screen.dart` | El backend no tiene un listado para quien recibe la invitación; se acepta pegando el código del correo. |

## Otros

- Paradas 04 y 05 de la bienvenida: los textos sobre la cadena pública y el anclaje siguen pendientes de confirmación con el equipo (no tocar hasta acordar redacción).
- M-26 «ayuda»: no está en la §1 aprobada de la Enmienda 2 y sus textos son los de M-20 (Carlos). Se añade cuando lleguen.
- Textos legales: enlazarlos en el registro y en el diálogo de re-aceptación cuando se publiquen.
- Versiones legales: fijas en `legal_versions.dart` (`v1-2026-10`); hay que actualizarlas a mano si cambian en el backend.
- Tema «Como el teléfono»: se añadió sin que nadie lo pidiera. Falta decidir si se queda o se quita (`lib/app/theme_mode_button.dart`, `lib/shared/theme/theme_controller.dart`).
- Barra de pestañas configurable y pestañas Explorar/Seguimiento de la web: no entran sin otra enmienda de ADR-043 (decisión del 2026-10-29).
- Rendimiento en un teléfono real: revisar Inicio con la ciudad y el seguimiento con `flutter run --profile` (las pruebas no miden fotogramas).
- Entregar con foto en Android/iOS reales: probado con pruebas automáticas y el flujo completo; falta probar la cámara en un teléfono.
