# Pendientes de Adonis (app móvil)

Rama `develop-Vprueba`, al día 2026-10-21. Todo lo de abajo compila; `flutter analyze` limpio y 269 pruebas en verde.

La enmienda 2 de ADR-043 está aprobada y ya están hechas M-03, M-04 (tamaño del texto), M-12, M-26, M-28, E-08, E-11 y E-12.

## Bloqueadas por un ADR sin aprobar

| ID | Falta | Archivo | Siguiente paso exacto |
|---|---|---|---|
| Entregar con foto | Aprobar `ADR-fotos-seccion-adonis-foto-de-entrega.md` (y la enmienda de dominio de `evidenceRef`) | `lib/features/physical_assets/presentation/asset_screen.dart` (tarjeta `asset.deliver.soon`), `field_action_flow.dart` | Sustituir la tarjeta por el paso de foto: JPEG 1600 px, q80, sin EXIF, < 500 KB; SHA-256 en `evidenceRef`; exigir conexión. |
| M25 | Aprobar `ADR-050-mapa-del-recorrido.md` | `lib/features/tracking/presentation/tracking_screen.dart` (`RouteTimeline`) | Añadir `flutter_map` + OSM bajo la línea de tiempo, con coordenadas del catálogo de lugares (sin GPS del empleado). Backend de M25 solo tras el ADR. |
| M27 | ADR de cuenta y sesiones (Carlos) + backend | `lib/features/account/presentation/account_screen.dart` | Añadir «Cambiar contraseña» en Cuenta; al cambiarla, cerrar las demás sesiones (y anular la biometría de los otros teléfonos). |

## Hechas en la app, esperando backend

| ID | Interfaz | Archivo | Siguiente paso exacto |
|---|---|---|---|
| M07 / M08 | Portada, logo y verificación | `lib/features/campaigns/data/campaign_api.dart`, `presentation/campaign_summary_card.dart`, `campaign_public_screen.dart` | Completado en la app: lee `organizationVerified` (bool), `organizationLogoUrl` y `coverImageUrl` en listado y detalle, mostrando portada 16:9, avatar circular con iniciales de reserva y sello «✓ Organización verificada». |
| M10 | `CampaignSearch` (`PublicCampaignSearch`) | `lib/features/campaigns/domain/public_campaign_search.dart`, `presentation/campaign_search_view.dart` | Ya funciona en Inicio y en «Ver todas» buscando en el teléfono sobre `GET /public/campaigns` (hasta 5 páginas). Cuando la enmienda de ADR-041 traiga búsqueda en el backend, implementar otra `CampaignSearch` con ese contrato. |
| M21 | `ImpactSource` (`UnavailableImpactSource`) | `lib/features/donations/domain/impact.dart`, `presentation/impact_card.dart` | Endpoint de impacto de la cuenta (Carlos/Manuel); implementar `ImpactSource` y pasarlo en `AppServices`. El panel ya está en Mis donaciones y se oculta sin datos. |
| M22 | `ReceiptSource` y `ReceiptSharer` | `lib/features/donations/domain/receipt.dart`, `presentation/receipt_view.dart` | Endpoint del comprobante (Manuel) e implementar `ReceiptSource`; para compartir, aprobar una dependencia (p. ej. `share_plus`) e implementar `ReceiptSharer`. |

## Otros

- Paradas 04 y 05: los textos sobre la cadena pública y anclaje siguen pendientes de confirmación con el equipo (no tocar hasta acordar redacción).
- Recuperación de contraseña: completada en la app vía `POST /auth/password-reset` (202 sin cuerpo) y hoja modal inferior `Key('forgot.sheet')`.
- Google y Billetera Web3: retirados del login al no existir soporte en la API de autenticación.
- Tipografía: eliminados todos los tamaños menores a 12 puntos en `lib/`.
- Cuenta (E-12): `GET /me` no trae el correo ni el nombre de la organización. Pedir al backend que los exponga y mostrarlos en `account_screen.dart`.
- Biometría (M-28): el backend que se use debe tener `/auth/device-credentials` y `/auth/device-login` (hoy solo están en la rama de pruebas del backend).

- E-03: la lectura operativa del backend no trae `assetType`, así que la ficha del activo no puede mostrar el tipo. Hay que pedirlo al backend.
- Tema «Como el teléfono»: se añadió sin que nadie lo pidiera. Falta decidir si se queda o se quita (`lib/app/theme_mode_button.dart`, `lib/shared/theme/theme_controller.dart`).
- Textos legales: enlazar los textos legales cuando se publiquen (en registro y diálogo de re-aceptación).
- Versiones legales: las versiones están fijas en `legal_versions.dart` (`v1-2026-10`) y hay que actualizarlas a mano si cambian en el backend.
