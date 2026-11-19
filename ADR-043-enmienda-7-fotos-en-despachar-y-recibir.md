# Enmienda 7 de ADR-043 — Foto opcional al despachar y al recibir

**Estado:** **APROBADA — Adonis, 2026-11-19** (comunicado por Manuel el 2026-11-19, junto con la revisión de PaxFide_Mv#17). *Texto original del estado, que se conserva:* PROPUESTA — espera aprobación. Redactada el 2026-11-16 por Manuel, con asistencia de Claude. Depende de la **Enmienda 2 de ADR-051** (backend, `Documentos/ADR-051-enmienda-2-fotos-de-los-pasos-y-copia-para-el-donante.md`), también PROPUESTA: sin ella no hay dónde subir la foto ni campo en el comando. **[Falta: quién aprueba (Carlos o Manuel), fecha y medio.]** No autoriza código.

## Por qué

Decisión de Manuel del 2026-11-15 (encargo, Tarea C, punto 4): fotos **opcionales** al registrar, despachar y recibir. En el móvil se registra poco (registrar es de la web, Enmienda 2 §1), así que esta enmienda cubre **despachar y recibir**. La entrega no cambia: foto obligatoria y con conexión (ADR-051 F5).

## Qué cambia

| # | Antes | Ahora |
|---|---|---|
| F1 | Despachar y recibir sin foto | Botón **«Añadir foto (opcional)»** en el formulario del paso: cámara directa (`image_picker`, ya aprobado en la Enmienda 2) o galería, con vista previa y la opción de quitarla. Mismo aviso fijo que la entrega: «Fotografía el lote o el acta, nunca a personas» (ADR-051 F7) |
| F2 | — | Con conexión: la app endereza la imagen (ADR-051 Q1 (a)), la sube a `POST /organizations/{id}/asset-evidence` con `step` (`DISPATCHED` o `RECEIVED`) y manda el comando con su `evidenceRef`. Si la subida falla (sin red, 413, 415, 503), dice por qué y ofrece **seguir sin foto**: nunca bloquea el paso |
| F3 | La cola sin conexión guarda despachar y recibir (D6, Enmienda 4) | **Igual, sin foto.** Sin conexión, el paso entra en la cola sin `evidenceRef` y el botón de foto dice que hace falta señal. **La cola nunca guarda bytes de imagen** de estos pasos (ADR-051 E2-3: es lo que F5 descartó para la entrega) |
| F4 | — | Un reintento por respuesta perdida usa el mismo `Command-Id` y el mismo `evidenceRef` (el backend admite volver a vincular la foto al mismo activo y paso) |

## Qué no cambia

- Ninguna dependencia nueva (A2/D12): `image_picker` ya está aprobado.
- La entrega: foto obligatoria, con conexión (F5).
- El móvil no registra lotes (Enmienda 2 §1); si algún día lo hace, la foto opcional de registrar entra con otra enmienda.
- El donante no ve estas fotos (ADR-051 Enmienda 2, E2-6).

## Definición de hecho (cuando se apruebe)

1. Despachar y recibir sin foto funcionan como hoy, con y sin conexión (aserción negativa: no se llama a la subida).
2. Con foto y conexión: la subida va antes del comando y el comando lleva su `evidenceRef`.
3. Sin conexión: el paso entra en la cola **sin** foto; la cola nunca contiene bytes de imagen (se comprueba en el almacén).
4. Subida fallida: mensaje claro y el paso se puede completar sin foto.
5. `flutter analyze` y `flutter test` completos, con su salida literal.
