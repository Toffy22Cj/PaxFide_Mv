# Pendientes de Adonis (app móvil)

Rama `develop-Vprueba`, al día 2026-10-20. Todo lo de abajo compila; `flutter analyze` limpio y 247 pruebas en verde.

## Bloqueadas por un ADR sin aprobar

| ID | Falta | Archivo | Siguiente paso exacto |
|---|---|---|---|
| M03 (gestos) | Aprobar la enmienda 2 de ADR-043 | `lib/app/app_shell.dart` | Añadir el deslizamiento entre pestañas del empleado sobre `_destinationsFor`, sin tocar Escanear (no es ruta). |
| M12 | Aprobar la enmienda 2 de ADR-043 | `lib/app/app_routes.dart` | Dar de alta la ruta que fije la enmienda y su pantalla. |
| E-08 | Aprobar la enmienda 2 de ADR-043 | `lib/app/app_routes.dart`, nueva `lib/features/campaigns/presentation/my_campaigns_screen.dart` | Ruta `/employee/campaigns` con `GET /me/campaigns` (ya lo usa `PredictionApi.myCampaigns`). |
| E-11 | Aprobar la enmienda 2 de ADR-043 | `lib/app/app_routes.dart`, `lib/features/physical_assets/presentation/asset_screen.dart` | Ruta `/assets/:assetRef/qr` con `screen_brightness` (dependencia de la enmienda) y `qr_flutter`. |
| E-12 / M26 | Aprobar la enmienda 2 de ADR-043 | `lib/app/app_shell.dart`, `lib/app/app_routes.dart` | Cuarta pestaña «Cuenta» (`/account`): ayuda, tema y cerrar sesión con confirmación. Cerrar sesión hoy está en la barra superior. |
| Entregar con foto | Aprobar `ADR-fotos-seccion-adonis-foto-de-entrega.md` (y la enmienda de dominio de `evidenceRef`) | `lib/features/physical_assets/presentation/asset_screen.dart` (tarjeta `asset.deliver.soon`), `field_action_flow.dart` | Sustituir la tarjeta por el paso de foto: JPEG 1600 px, q80, sin EXIF, < 500 KB; SHA-256 en `evidenceRef`; exigir conexión. |
| M25 | Aprobar `ADR-050-mapa-del-recorrido.md` | `lib/features/tracking/presentation/tracking_screen.dart` (`RouteTimeline`) | Añadir `flutter_map` + OSM bajo la línea de tiempo, con coordenadas del catálogo de lugares (sin GPS del empleado). Backend de M25 solo tras el ADR. |
| M08 | ADR de fotos y backend (Manuel) | `lib/features/campaigns/presentation/campaign_public_screen.dart` | Portada de la convocatoria y foto de la organización cuando el ADR fije proveedor y formato. |
| M27 | ADR de cuenta y sesiones (Carlos) + backend | Pantalla Cuenta (E-12) | Cambiar y recuperar contraseña; al cambiarla, cerrar las demás sesiones. |
| M28 | Enmienda 2 de ADR-043 (`local_auth`) | La biometría está en la rama `claude/focused-goodall-meb6sh` | Llevar la biometría (solo en el login) a esta rama y poner el logo en el recuadro «Entrar con biometría». |

## Hechas en la app, esperando backend

| ID | Interfaz | Archivo | Siguiente paso exacto |
|---|---|---|---|
| M07 | `OrganizationVerification` (`PublicFieldVerification`) | `lib/features/campaigns/domain/organization_verification.dart` | Backend (Manuel): exponer `verificationStatus` en `GET /public/campaigns/{publicCode}`. La app ya lo lee; con `VERIFIED` se ve la insignia. |
| M10 | `CampaignSearch` (`UnavailableCampaignSearch`) | `lib/features/campaigns/domain/campaign_search.dart`, `presentation/campaign_search_view.dart` | Enmienda de ADR-041 con búsqueda y filtros en `GET /public/campaigns`; implementar `CampaignSearch` con ese contrato y montar `CampaignSearchView` en la ruta `/campaigns` (hoy diferida). |
| M21 | `ImpactSource` (`UnavailableImpactSource`) | `lib/features/donations/domain/impact.dart`, `presentation/impact_card.dart` | Endpoint de impacto de la cuenta (Carlos/Manuel); implementar `ImpactSource` y pasarlo en `AppServices`. El panel ya está en Mis donaciones y se oculta sin datos. |
| M22 | `ReceiptSource` y `ReceiptSharer` | `lib/features/donations/domain/receipt.dart`, `presentation/receipt_view.dart` | Endpoint del comprobante (Manuel) e implementar `ReceiptSource`; para compartir, aprobar una dependencia (p. ej. `share_plus`) e implementar `ReceiptSharer`. |

## Otros

- E-03: la lectura operativa del backend no trae `assetType`, así que la ficha del activo no puede mostrar el tipo. Hay que pedirlo al backend.
- Tema «Como el teléfono»: se añadió sin que nadie lo pidiera. Falta decidir si se queda o se quita (`lib/app/theme_mode_button.dart`, `lib/shared/theme/theme_controller.dart`).
