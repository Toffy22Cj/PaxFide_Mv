# Pendientes de Adonis (app móvil)

Rama `chore/landing-bienvenida-movil`, al día 2026-11-07. `flutter analyze` limpio y la suite completa en verde (evidencia en `Documentos/evidencia-mobile/`).

Hechas: todas las funciones de la lista del 16 de octubre a nombre de Adonis que no dependen de un ADR sin aprobar o de un contrato que no existe. El detalle está en la §6 y la §7 de la Enmienda 2 de ADR-043. Lo último (2026-10-28): términos y condiciones, recuperar y cambiar la contraseña, correo y nombre en Cuenta, desactivar la cuenta, Mi impacto, entregar con foto, integridad visible con sello y huella por paso, y el tipo del activo en la ficha. El 2026-10-29: la app sigue a la web en Inicio (con la ciudad), la tarjeta de convocatoria, el seguimiento, los primeros pasos, Mis donaciones, las cargas y las transiciones (§8 de la Enmienda 2).

## Hechas el 2026-11-02 y el 2026-11-07 (correcciones del primer bloque, mapa y municipio)

| ID | Qué | Dónde |
|---|---|---|
| M25 | Mapa del recorrido (2026-11-07): `ADR-mapa-del-recorrido.md` (número por asignar). La app se adapta al backend: dibuja la zona sellada de cada paso (`locationZone`, enmienda 2 de ADR-029) con su tabla de zonas (`assets/map/zonas.json`, generada con `scripts/generar_zonas_mapa.py` desde el catálogo DIVIPOLA del backend y las coordenadas del DANE). Sin cambios en el backend | `lib/features/tracking/presentation/tracking_map_view.dart`, `domain/tracking_map.dart` |
| — | Recibir y Entregar piden el municipio (DIVIPOLA): `develop` del backend lo exige desde el 2026-11-02 (enmienda 2 de ADR-029; sin él, 400) | `field_action_flow.dart`, `shared/location/` |
| M28 | Biometría sobre `develop` del backend (fusionada en la rama de trabajo del backend) y con las reglas del login: `EmailNotVerified` y `AcceptanceRequired` también al entrar con la huella | `lib/features/auth/biometrics/biometric_login.dart`, `login_screen.dart` |
| — | Correo sin confirmar en el login (403 `EmailNotVerified`, ADR-050 Enmienda 2) con «Reenviar el correo de confirmación»; el registro ya no dice «Ya puedes entrar» | `login_screen.dart`, `register_screen.dart`, `auth_api.dart` |
| C1 | Cuenta del donante sin la tarjeta de invitación (es de la E-12 del empleado) | `account_screen.dart` |
| C2 | Crear cuenta pide «Confirmar contraseña» | `register_screen.dart` |
| C3 | Textos legales sin «(versión …)» | `register_screen.dart`, `legal_acceptance_dialog.dart` |
| C4a | Cuenta del donante sin la fila «Organización» | `account_screen.dart` |
| C5/C6 | Escáner por perfil (donante: convocatorias; empleado: lotes y referencia escrita, E-02); un texto suelto ya no abre `/assets/{texto}`; «Seguir una donación» en vez de callejones sin salida | `app/qr_scanner_sheet.dart` |
| C5c | «Seguir una donación» pega solo el código copiado y abre los enlaces de PaxFide pegados | `tracking_screen.dart` |
| C7 | QR de la convocatoria en la misma pantalla | `campaign_public_screen.dart`, `shared/widgets/qr_sheet.dart` (`QrPanel`) |

## Pendientes de este bloque

| ID | Falta | Siguiente paso exacto |
|---|---|---|
| C4b | Cuenta del empleado: el nombre (y el logo) de su organización en vez de «Perteneces a una organización» | El backend no da el nombre al `EMPLOYEE` (`GET /organizations/{id}` le da 403; el logo sí lo puede leer). Pedir a Manuel una lectura del nombre de la propia organización para cualquier miembro |
| — | Escanear el código de seguimiento o sacarlo de un QR/enlace | Necesita una enmienda de ADR-043 §0 (Carlos): hoy el parser descarta el código a propósito |
| — | ADR del mapa: falta la firma de quien lo aprueba en nombre del equipo y reservar su número en el catálogo del backend | Escribirla en el `Estado` de `ADR-mapa-del-recorrido.md` |
| — | Mapa en producción | Contratar o montar un proveedor de teselas y ponerlo en `PAXFIDE_MAP_TILE_URL` |

## Hechas en la app, esperando backend

| ID | Interfaz | Archivo | Siguiente paso exacto |
|---|---|---|---|
| M10 | `CampaignSearch` (`PublicCampaignSearch`) | `lib/features/campaigns/domain/public_campaign_search.dart`, `presentation/campaign_search_view.dart` | Ya funciona buscando en el teléfono sobre `GET /public/campaigns` (hasta 5 páginas). Cuando la enmienda de ADR-041 traiga búsqueda en el backend, implementar otra `CampaignSearch` con ese contrato. |
| M22 | `ReceiptSource` y `ReceiptSharer` | `lib/features/donations/domain/receipt.dart`, `presentation/receipt_view.dart` | Endpoint del comprobante (Manuel) e implementar `ReceiptSource`; para compartir, aprobar una dependencia (p. ej. `share_plus`) e implementar `ReceiptSharer`. |
| M28 | Biometría (visible y funcionando) | `lib/features/auth/biometrics/` | El 2026-11-02 se fusionó sobre `develop` en la rama de trabajo del backend (`claude/magical-hopper-7w941b` de Donaciones), con las reglas del login. Falta el PR de esa rama a `develop`. |
| E-12 | Invitaciones en Cuenta | — | Quitada del donante el 2026-11-02 (C1). La invitación se acepta desde el enlace del correo en la web (ADR-049). |

## Otros

- Paradas 04 y 05 de la bienvenida: los textos sobre la cadena pública y el anclaje siguen pendientes de confirmación con el equipo (no tocar hasta acordar redacción).
- M-26 «ayuda»: no está en la §1 aprobada de la Enmienda 2 y sus textos son los de M-20 (Carlos). Se añade cuando lleguen.
- Textos legales: enlazarlos en el registro y en el diálogo de re-aceptación cuando se publiquen.
- Versiones legales: fijas en `legal_versions.dart` (`v1-2026-10`); hay que actualizarlas a mano si cambian en el backend.
- Tema «Como el teléfono»: se añadió sin que nadie lo pidiera. Falta decidir si se queda o se quita (`lib/app/theme_mode_button.dart`, `lib/shared/theme/theme_controller.dart`).
- Nombre del paquete Android: `com.paxfide.mobile` (y `com.paxfide.mobile.demo`) desde el 2026-10-29, para registrar la app en Google Cloud («Entrar con Google»). La SHA-1 registrada es la de la llave de depuración del PC de Adonis. `google_sign_in` es una dependencia nueva: necesita la aprobación de Carlos (A2) antes de agregarla. iOS sigue con `com.example.paxfideMobile`.
- Barra de pestañas configurable y pestañas Explorar/Seguimiento de la web: no entran sin otra enmienda de ADR-043 (decisión del 2026-10-29).
- Rendimiento en un teléfono real: las causas del lag se corrigieron (§10 de la Enmienda 2); falta comprobarlo en un teléfono con un APK de release o `flutter run --profile` (las pruebas no miden fotogramas).
- Entregar con foto en Android/iOS reales: probado con pruebas automáticas y el flujo completo; falta probar la cámara en un teléfono.

## Auditoría de Carlos (2026-10-29, `revision-auditoria-paxfide-mobile-2026-10-29.md`)

Corregido en la app, cada punto en su commit con su prueba:

| Punto | Qué se hizo |
|---|---|
| §3 / §6.6 · 401 sintético | Sin JWT la petición «no salió» (`MissingCredentialException`): la operación sigue `PENDING`, nunca `FAILED` |
| M-05 · ADR-051 F5 | La entrega nunca queda en cola sin conexión: se retira y se pide «Reintentar» con señal (la foto ya subida no se vuelve a subir) |
| M-04 | «Reintentar con el mismo envío» en las operaciones sin confirmar, junto a «Verificar estado» |
| S-04 | La copia de la foto se borra de la caché al leerla (solo dentro de la caché; nunca un original) |
| S-02 | El enlace de pago solo se abre si es `https` hacia la web o la API de PaxFide; si no, solo se copia |
| S-06 | `android:allowBackup="false"` |

Esperando decisión de Carlos (no se tocan hasta que decida):

- **DC-1 a DC-8** de la §7: rama, biometría (S-01: se aplicó la opción (b) en el backend; sigue siendo un token portador y Carlos tiene que aceptar ese riesgo por escrito o pedir la (a)), Enmiendas 2 y 3 y sección de fotos (P-1, P-3, P-4), las cuatro dependencias (P-2), biometría definitiva, `url_launcher`, `trackingCode` en «Ver el recorrido» (S-03, DDM-25), firma de la app (S-05) y dónde escribir que las donaciones de donantes comunes no son públicas.
- **S-07** (capturas de pantalla): aceptarlo como deuda o protegerlo; protegerlo pide código nativo o una dependencia.
- **Prueba contra el backend real (§6.7):** volver a ejecutarla con el backend local y pegar la salida literal en el PR.
- **Ramas (§6):** Carlos pide cada corrección en su rama `fix/`. Esta sesión solo puede subir a `claude/…`; las correcciones van en commits separados para poder pasarlas a ramas `fix/`.
