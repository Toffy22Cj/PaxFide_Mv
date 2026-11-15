# ADR de fotos y almacenamiento — Sección de Adonis: foto de entrega (para que Carlos la integre)

**Estado:** Aprobado para el móvil (Adonis, 2026-10-28), sobre lo que el backend implementó en ADR-051 · **Fecha:** 2026-10-20 · **Autor:** Adonis

## Decisión propuesta
1. **Obligatoria.** Entregar (`POST /physical-assets/{assetRef}/deliver`) exige una foto.
2. **Huella, no imagen, en la cadena.** La foto se sube a un almacenamiento privado en la nube (acceso solo del backend, URL firmada de corta duración para la organización). En `evidenceRef` se guarda su **SHA-256 en hexadecimal (64 caracteres)**. La imagen, que puede mostrar personas, nunca sale del almacenamiento privado y no queda en el evento inmutable.
3. **Enmienda de dominio.** Hoy `ASSET_DELIVERED` acepta `evidenceRef` vacío. Exigirlo no vacío (y con formato de 64 hex) es una enmienda de dominio en el backend.
4. **Sin conexión: se recomienda exigir conexión para entregar.** Despachar y recibir siguen funcionando sin conexión; entregar no.
   - Motivo: guardar la foto en el teléfono hasta poder subirla mantiene una imagen de beneficiarios (posibles menores) en un dispositivo que se puede perder, y complica la cola (subida + comando, con estados ambiguos dobles).
   - Alternativa descartada: foto cifrada en el almacenamiento privado de la app dentro de la cola, borrada al confirmarse la subida.
5. **Formato:** JPEG, lado mayor 1600 px, calidad 80, sin metadatos EXIF (se quitan ubicación y modelo del teléfono antes de calcular la huella). Tamaño objetivo < 500 KB.
6. **Personas en la foto:** se recomienda fotografiar la ayuda entregada (bolsas, cajas, el lugar) y no a las personas. Si aparece un menor o un beneficiario: la foto queda solo en el almacenamiento privado, nunca se muestra en la app del donante ni en la web pública, y solo la ve la organización. Retención: 2 años, luego se borra; la huella permanece.

## Consecuencias
- Backend: subida de foto (contrato nuevo), validación de `evidenceRef`.
- Móvil: dependencia para la cámara (`image_picker`) y para la huella (`crypto`), enmienda de A2/D12.

## Aprobación e implementación (2026-10-28)

El backend resolvió su parte en ADR-051 (Tareas 4 y 5). El móvil se ajusta a lo implementado; lo de arriba no se reescribe:

- **Huella (puntos 2 y 3):** la calcula el **backend** sobre la imagen ya limpia (sin EXIF, GPS ni comentarios) y la devuelve como `evidenceRef = "sha256:<64 hex>"`. La entrega rechaza cualquier otro formato (400 `InvalidEvidenceRef`). Por eso el móvil **no** necesita `crypto`.
- **Subida:** `POST /organizations/{organizationId}/delivery-evidence`, `multipart/form-data` con el campo `file`, JPEG o PNG de hasta 5 MB, sin `Command-Id`. Una foto solo sirve para un activo (409 `EvidenceAlreadyBound`).
- **Sin conexión (punto 4):** se adopta la recomendación. La foto se sube con conexión antes de entregar; si no hay conexión no se registra nada y la foto no se guarda en el teléfono. La entrega, ya con su `evidenceRef`, sí puede quedar en el Outbox.
- **Formato (punto 5):** `image_picker` con lado mayor 1600 px y calidad 80.
- **Personas (punto 6):** el formulario avisa de fotografiar la ayuda entregada y no a las personas. La foto nunca se muestra al donante: en el seguimiento solo sale «Evidencia de entrega registrada».
- **Dependencia:** `image_picker` ^1.2.4 (nota en la Enmienda 2 de ADR-043, §2).
