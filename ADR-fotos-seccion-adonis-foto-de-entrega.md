# ADR de fotos y almacenamiento — Sección de Adonis: foto de entrega (para que Carlos la integre)

**Estado:** Propuesto · **Fecha:** 2026-10-20 · **Autor:** Adonis

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
