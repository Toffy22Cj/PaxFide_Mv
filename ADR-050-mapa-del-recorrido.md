# ADR-050 (número por asignar) — Mapa del recorrido (M-25)

**Estado:** Propuesto · **Fecha:** 2026-10-20 · **Autor:** Adonis

## Contexto
El donante quiere ver por dónde pasó su ayuda. Hoy los eventos del activo guardan ubicaciones como **referencias** (`locationZone`, `facilityLocation`), sin coordenadas. La ubicación del empleado que despacha o entrega es un **dato personal** (Ley 1581).

## Decisión propuesta
1. **Coordenadas fuera de los eventos inmutables.** Los eventos siguen guardando solo la referencia del lugar. Las coordenadas viven en un catálogo aparte de **lugares** (bodegas, puntos de entrega) que administra la organización: `locationRef → {lat, lon, nombre público}`. Se pueden corregir o borrar sin tocar la cadena de custodia.
2. **Nunca la ubicación en vivo del empleado.** El mapa dibuja los lugares registrados del recorrido, no el GPS del teléfono. Así no hace falta permiso de ubicación, consentimiento ni retención de datos personales. Si algún día se quisiera GPS, iría con consentimiento explícito, finalidad y borrado a los 30 días (nuevo ADR).
3. **Proveedor: OpenStreetMap con `flutter_map`.** Waze no sirve: su Transport SDK es solo para empresas de transporte asociadas y **no ofrece un mapa embebible** para dibujar un recorrido propio; los deep links solo abren la app de Waze en un punto ([Waze Transport SDK](https://developers.google.com/waze/intro-transport?hl=en), [Waze Deep Links](https://developers.google.com/waze/api)). `flutter_map` es gratuito, sin clave, y dibuja marcadores y una línea entre lugares. Las teselas públicas de OSM tienen límites de uso: en producción, un proveedor de teselas o uno propio.

## Consecuencias
- Backend: catálogo de lugares (contrato nuevo) y una lectura pública del recorrido con `{lat, lon, nombre}` por paso, sin datos de personas.
- Móvil: dependencia `flutter_map` (+ `latlong2`), enmienda de A2/D12.
- Un lugar sin coordenadas se muestra solo en la línea de tiempo, no en el mapa.
