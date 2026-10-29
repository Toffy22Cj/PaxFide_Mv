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

*Nota (2026-10-28, aprobada por Adonis):* se añade **`image_picker` ^1.2.4** para la foto de entrega (cámara y galería; ver §7). No hace falta `crypto`: la huella la calcula el backend al recibir la foto (ADR-051 F3).

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

## 5. Diseño visual (Figma «Sin título», 2026-10-21)

Las pantallas siguen el diseño de Figma (01 Acceso e inicio, 02 Convocatoria y donación, 03 Seguimiento y recorrido, 04 Operación, 05 Predicción y sistema), con la **navegación de esta enmienda** (no la del Figma) y con las funciones que el Figma no dibuja (logros, filtros, importes sugeridos, progreso, Mis convocatorias, QR a pantalla completa).

- **Colores:** el modo claro usa solo la paleta oficial. El modo oscuro es la misma paleta en contraste oscuro: cada color se invierte en luminosidad (HSL, `L → 1 − L`), de modo que los verdes oscuros de los botones pasan a verdes claros y los fondos claros pasan a casi negros; las tarjetas destacadas y los chips usan los tonos oscuros de la paleta tal cual. Lo comprueba `test/architecture/design_tokens_test.dart`.
- **Diferencias con el Figma:** el donante no ve la referencia del bien («Lote …») en el seguimiento (regla de privacidad existente); la tarjeta de predicción usa el azul de la paleta en lugar del morado, que no está en la paleta; el aviso de la revisión dice «Esto queda registrado para siempre» (texto pedido en la reunión).

## 6. Estado de las funciones (2026-10-28, rama `chore/landing-bienvenida-movil`)

Registro de lo que ya está en el código y no estaba documentado en ningún ADR. Se comprobó contra el backend `develop` de `Toffy22Cj/Donaciones` (`993c3e8`). Las secciones anteriores no se reescriben.

### 6.1 Funciones del donante implementadas

| Función | Qué hace | Dónde |
|---|---|---|
| M-07 | Sello «✓ Organización verificada», solo si `organizationVerified` es `true` (Enmienda 3) | `campaigns/domain/organization_verification.dart`, `campaign_summary_card.dart` |
| M-09 | Progreso de la convocatoria: porcentaje de la meta, días que quedan y meta alcanzada | `campaigns/domain/campaign_progress.dart` |
| M-10 | Buscar, filtrar y ordenar convocatorias **en el teléfono** sobre `GET /public/campaigns` (hasta 5 páginas). «Ver todas» abre la búsqueda sin ruta propia: `/campaigns` sigue diferida | `public_campaign_search.dart`, `campaign_search_view.dart` |
| M-11 | Donar sin cuenta, o iniciar sesión antes de pagar para verla luego en «Mis donaciones» | `donations/presentation/donate_sheet.dart` |
| M-12 | «Abrir el pago» con `url_launcher` (§4) | `donate_sheet.dart` |
| M-14 | Importes sugeridos: tocar uno escribe la cifra en el campo | `shared/money.dart`, `donate_sheet.dart` |
| M-15 | Mis donaciones: filtros por estado del pago y total confirmado por moneda | `my_donations_screen.dart` |
| M-16 | Detalle de una donación. «Ver el recorrido» usa el código de la cuenta en memoria, sin escribirlo ni guardarlo | `my_donations_screen.dart`, `account_donations_api.dart` |
| M-17 | Línea de tiempo del recorrido de un bien, con el paso actual resaltado | `tracking/presentation/tracking_screen.dart` |
| M-19 | Botón «Pegar» del código en el seguimiento y en el escáner | `tracking_screen.dart`, `app/qr_scanner_sheet.dart` |
| M-21 | Panel «Mi impacto» en Mis donaciones, detrás de `ImpactSource`. Hoy usa `UnavailableImpactSource`: sin datos, el panel no se muestra | `donations/domain/impact.dart`, `impact_card.dart` |
| M-22 | Comprobante dibujado como tarjeta y capturable como imagen, detrás de `ReceiptSource` y `ReceiptSharer`. Hoy los dos son `Unavailable…` | `donations/domain/receipt.dart`, `receipt_view.dart` |
| M-23 | «Tus logros», solo visibles para el propio donante, sin compartir | `donations/domain/achievements.dart` |
| M-35 | Logo de PaxFide en vector, el mismo del landing (Enmienda 3) | `shared/widgets/pax_logo.dart` |

### 6.2 Lo que el backend ya tiene y la app aún no usa

| Función | Contrato existente | Falta en la app |
|---|---|---|
| M-21 Mi impacto | `GET /account/impact` → `{donationsCount, totals, campaignsSupported, deliveredUnits, truncated}` | Implementar `ImpactSource`. La forma no coincide con `MyImpact` (`byCampaign`, `distinctRecipients`): hay que adaptar el modelo |
| M-27 Cambiar contraseña | `POST /account/password` → `200 {token}`; la app sustituye el token y las demás sesiones quedan revocadas | La opción en Cuenta |
| E-12 Correo y nombre en Cuenta | `GET /account` → `{email}`; `GET`/`PUT /account/profile` → `{email, givenName?, familyName?}` | Mostrarlos en `account_screen.dart`. Supera el límite de §4 («`GET /me` no trae el correo») |
| Entregar con foto | `POST /organizations/{id}/delivery-evidence` → `201 {evidenceRef}` (ADR-051) | Sigue pendiente de aprobar `ADR-fotos-seccion-adonis-foto-de-entrega.md`; hoy `evidenceRef` se escribe a mano |
| Seguimiento verificable | `eventHash` y `anchorProof` por paso; `GET /donations/tracking/integrity` | Mostrarlos en el seguimiento (la web ya lo hace) |
| Desactivar la cuenta | `POST /account/deactivate` (ADR-050 D6) | Decidir si va en el móvil |

### 6.3 Limitaciones conocidas

- **M-28 (biometría):** `/auth/device-credentials` y `/auth/device-login` no están en `develop` del backend; solo en la rama `claude/focused-goodall-meb6sh`. Contra `develop`, activar la biometría falla.
- **M-22 (comprobante):** no hay endpoint en el backend.
- **M-25 (mapa del recorrido):** depende de `ADR-050-mapa-del-recorrido.md`, sin aprobar.
- **M-10:** la búsqueda en el servidor no existe; la del teléfono cubre hasta 5 páginas (100 convocatorias).

## 7. Implementación (2026-10-28, rama `chore/landing-bienvenida-movil`)

Decisiones de Adonis del 2026-10-28: entregar con foto se implementa (el backend ya tenía ADR-051); la biometría se queda visible; desactivar la cuenta va en Cuenta; el seguimiento muestra el estado y las huellas, sin recalcular la prueba en el teléfono. Con esto, las filas de §6.2 quedan hechas y la §6.1 se actualiza así:

| Función | Cómo quedó | Dónde |
|---|---|---|
| E-12 / M-26 Cuenta | Correo y nombre (`GET`/`PUT /account/profile`); el nombre se edita y es privado | `account/data/account_api.dart`, `account_screen.dart` |
| M-27 Cambiar contraseña | En Cuenta → Seguridad. `POST /account/password`; el token nuevo sustituye al anterior con la misma persistencia («Recordarme»), y las demás sesiones quedan cerradas. Un 500 lleva a entrar otra vez (ADR-038 #7) | `account_screen.dart`, `SessionController.replaceToken` |
| M-30 Desactivar la cuenta | En Cuenta → Seguridad, con la contraseña. Explica los 409 (representante, responsable de convocatoria, administrador de plataforma). Al confirmarse se cierra la sesión y se olvida la biometría del teléfono | `account_screen.dart` |
| M-21 Mi impacto | `ApiImpactSource` sobre `GET /account/impact`: donaciones confirmadas, convocatorias apoyadas, total por moneda y barras de unidades **entregadas en las convocatorias apoyadas** (no atribuidas al donante, P-M21-4). Sin donaciones, no se muestra | `donations/data/account_impact_api.dart`, `impact_card.dart` |
| Entregar con foto (E-04, E-05) | La foto es obligatoria: el formulario la pide (cámara o galería, 1600 px, JPEG 80) con el aviso de fotografiar la ayuda y no a las personas; la revisión la muestra. Al confirmar se sube primero (`POST /organizations/{id}/delivery-evidence`, multipart, **con conexión**) y la entrega va al Outbox con el `evidenceRef` devuelto. La foto nunca se guarda en el teléfono; reintentar no la vuelve a subir | `core/media/photo_picker.dart`, `delivery_evidence_api.dart`, `field_action_flow.dart` |
| M-18 Integridad visible | Tarjeta con el resultado del servidor (`GET /donations/tracking/integrity`): verificado, parcial, pendiente, sin comprobar o diferencia; detalle por lote con red, transacción, raíz y fecha | `tracking_api.dart`, `tracking_screen.dart` |
| M-17 (ampliada) | Cada paso muestra su sello (`anchorStatus`), su huella (`eventHash`, se copia) y, en la entrega, «Evidencia de entrega registrada» | `tracking_screen.dart` |
| E-03 Tipo del activo | La ficha muestra el `assetType`; Mi día y Mis convocatorias lo anteponen | `physical_asset_api.dart`, `asset_screen.dart` |

**Transporte:** `ApiClient` gana `put` y `postFile` (multipart con un solo archivo). Siguen sin dependencias nuevas de red.

**Sigue pendiente** (no se programa hasta tener contrato o ADR aprobado):
- M-22 comprobante: no hay endpoint.
- M-25 mapa del recorrido: `ADR-050-mapa-del-recorrido.md` sin aprobar.
- M-10 búsqueda en el servidor: sin enmienda de ADR-041; la búsqueda en el teléfono sigue.
- M-28 biometría: la app está lista, pero `/auth/device-credentials` y `/auth/device-login` solo están en la rama `claude/focused-goodall-meb6sh` del backend.
- M-26 «ayuda»: no figura en la §1 aprobada y sus textos son los de M-20 (Carlos). No se redacta hasta tenerlos.
- E-12 invitaciones pendientes: el backend no tiene listado para quien recibe la invitación; se sigue aceptando con el código del correo.

**Verificación:** `flutter analyze` sin avisos y la suite completa en verde; la evidencia de `scripts/ci-local.sh` queda en `Documentos/evidencia-mobile/`.

## 8. Fidelidad con el front web (2026-10-29, rama `chore/landing-bienvenida-movil`)

Decisiones de Adonis del 2026-10-29: la app se adapta a lo que ya implementó la web (`develop`), sin salirse de su alcance (donante y operador de campo; el panel de la organización sigue siendo de la web) y con la fluidez como prioridad. La barra de pestañas **se queda como en la §1** (abajo, sin las pestañas Explorar ni Seguimiento de la web): cambiarla pediría otra enmienda. La ciudad de fondo de Inicio **sí** entra, con pausa. Sin dependencias nuevas (`animations` no se añade: las transiciones se hacen a mano).

| Pieza de la web | En la app | Dónde |
|---|---|---|
| Tiempos y curvas (`globals.css`, `movimiento.html`) | `PaxMotion`: rápido 150, normal 300, lento 450 ms y las curvas estándar, salida, ida y vuelta y rebote. «Reducir movimiento» del teléfono deja todo quieto o instantáneo | `shared/motion/pax_motion.dart` |
| Transiciones de pantalla | Deslizar (350 ms, con vuelta deslizando desde el borde) para los detalles; fundido para las pestañas; eje Z para bienvenida, entrar, registrarse e Inicio; la portada de la convocatoria vuela de la tarjeta a su pantalla (Hero); hoja inferior de 350 ms; revelado circular con «¡Gracias!» al confirmarse una donación | `app/router/pax_page.dart`, `shared/motion/pax_route.dart`, `circular_reveal.dart` |
| Cargas (`components/loaders`) | Cubos encadenados (carga de pantalla), puntos de marca (botones que envían), esqueleto con brillo (listas y tarjetas), árbol de Merkle (integridad) y camión (lote en camino) | `shared/widgets/loaders.dart` |
| Tarjeta de convocatoria (`CampaignCard`, variante 01) | Igual: portada, logo o inicial, «Verificada», título, «$X de $Y (N %)» y «Cierra el …». La variante 15 se quita | `campaign_summary_card.dart` |
| Inicio (`HomeScreen`, `paxfide-home.html`) | Saludo por la hora con nombre e iniciales, aviso «Completa tu perfil», «Seguir una donación» destacada (el código va en memoria), «Sellado en blockchain», «Cierran pronto» / «Convocatorias abiertas» y «Tus donaciones» con fecha, organización y medio de pago. Las tarjetas entran escalonadas. El operador ve primero Operaciones; la Predicción sigue como excepción | `app/home_screen.dart` |
| Ciudad (`CityBackground`) | Mismo valle (misma semilla), día y noche según el tema, indicador «Sector: Plaza central» y pausa que se recuerda (también en Cuenta → Apariencia y ciudad) | `shared/city/` |
| Primeros pasos (`LoginScreen` + `NameGate`) | Tras crear la cuenta, al entrar por primera vez: bienvenida y «¿Cómo te llamamos?» (opcional) | `account/presentation/first_steps_screen.dart` |
| Seguimiento (`TrackingTimeline`, `StepDetail`, `paxfide-linea-tiempo.html`) | Las tres columnas pasan a una: cabecera de la historia, árbol Donada → lotes → sublotes (`parentAssetRef`) con sus pasos, el camión si va en camino, la carretera en serpiente por lote y el detalle de cada paso en una hoja (huella, foto, anclaje). Comprobar la prueba en el teléfono sigue fuera (decisión del 2026-10-28) | `tracking/domain/tracking_story.dart`, `tracking_story_view.dart`, `tracking_screen.dart` |
| Mis donaciones (`AccountDonationsScreen`) | Esqueleto, «Seguir con un código», fecha, organización y medio de pago, y «Ver convocatoria» en el detalle | `my_donations_screen.dart` |

**Excepción a la regla de colores.** Como en la web (D-P1, DF7-11), la ciudad es una ilustración con su propia paleta de día y de noche; sus colores viven solo en `shared/city/city_palette.dart`, que `design_tokens_test` admite como único archivo además de `pax_tokens.dart`. Nada fuera de la ciudad los usa.

**Rendimiento (reglas que siguen todas las animaciones).** Un solo reloj por pieza y pintura con `CustomPainter(repaint:)` dentro de un `RepaintBoundary`, sin reconstruir widgets en cada fotograma; los bucles se paran fuera de pantalla (`TickerMode`), con «reducir movimiento» y, la ciudad, en cuanto el contenido la tapa al desplazar. La ciudad pinta el suelo fijo una sola vez en una imagen, descarta lo que cae fuera de la pantalla y va a 30 fotogramas por segundo, para dejar al desplazamiento, los gestos y las transiciones todo el margen del teléfono. Ningún retraso usa temporizadores sueltos (los escalonados van dentro de la animación).

**Verificación:** `flutter analyze` sin avisos y la suite completa en verde (pruebas nuevas de movimiento, ciudad, Inicio, primeros pasos y seguimiento); la evidencia de `scripts/ci-local.sh` queda en `Documentos/evidencia-mobile/`.
