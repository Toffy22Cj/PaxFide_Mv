# ADR (número por asignar) — Mapa del recorrido en la app (M-25)

**Estado:** Aprobado para implementar por encargo del equipo, 2026-11-07. Falta la firma de quien lo aprueba en nombre del equipo (regla 1 de `reglas-equipo-y-agentes.md`) y reservar su número en el catálogo de `documento-maestro-proyecto.md` del backend. · **Autor:** Adonis

**Origen:** M-25 del documento «Funciones de la app móvil y pantallas del empleado» (16 de octubre): «Mapa del recorrido · Adonis (completo, con su ADR) · Asignada, ADR primero», y la decisión 8 («Mapa sí, con ADR»).

**Sustituye** al borrador «ADR-050 (número por asignar)» del 2026-10-20 (el 050 es «Cuenta y sesiones» en el backend) y a la versión del 2026-11-02 que proponía cambios en el backend: esos cambios no se hicieron. **La app se adapta al backend tal como está.**

## Contexto

- El donante ve el recorrido de su aporte como una línea de tiempo (M-17) y quiere verlo también sobre un mapa.
- **Lo que da el backend** (`develop` desde el 2026-11-02, enmienda 2 de ADR-029, aprobada por Manuel): cada paso del seguimiento lleva su zona pública en `locationZone`, el texto **sellado** en el evento, «MUNICIPIO, DEPARTAMENTO» tal cual el catálogo DIVIPOLA (`SealedZone.of`: solo el municipio si los dos nombres son iguales, «BOGOTÁ, D.C.»). El despacho lleva la zona del paso anterior. Los pasos de antes del cambio siguen con `location_reference` como respaldo y pueden llegar sin zona.
- **El backend no da coordenadas**, y el catálogo DIVIPOLA de `GET /public/locations` tampoco las trae.
- La ubicación del empleado es un dato personal (Ley 1581), y un punto de entrega exacto puede señalar dónde vive un beneficiario.

## Decisión

### D1. La zona sale del backend, sin cambiarlo
La app usa `locationZone` de `GET /donations/tracking` (cada lote) y de su historial (cada paso). No pide ni añade nada al backend.

### D2. Las coordenadas: una tabla de zonas dentro de la app
- `assets/map/zonas.json`: el punto de cada zona DIVIPOLA, por el mismo texto que sella el backend. El punto es el **centro del municipio** del DANE, nunca un lugar exacto.
- Se genera con `scripts/generar_zonas_mapa.py` a partir del catálogo del backend (`app/src/main/resources/divipola/divipola.json`, el mismo de `GET /public/locations`) y de la DIVIPOLA del DANE con coordenadas publicada en datos.gov.co (conjunto `gdxc-w37w`), unidos por código de municipio. Versión `DIVIPOLA-2026-09`: 1122 zonas, todas con punto.
- La búsqueda no distingue mayúsculas ni espacios de los extremos. Una zona que no está en la tabla (texto libre antiguo de `location_reference`, o vacío) **no tiene punto y no se dibuja**: nunca se inventa uno.
- Si el backend cambia de catálogo, se vuelve a generar la tabla con el script.

### D3. Nunca la ubicación del teléfono
La app no pide permiso de ubicación ni lee el GPS.

### D4. El mapa: `flutter_map` + `latlong2` sobre OpenStreetMap
- **Dependencias nuevas** (enmienda de ADR-043 A2/D12): `flutter_map` y `latlong2`. Sin geolocalización ni caché de teselas en disco.
- **Teselas:** `PAXFIDE_MAP_TILE_URL` al compilar; en desarrollo, la de OpenStreetMap. Atribución «© OpenStreetMap contributors» siempre visible y el identificador de la app como `User-Agent`. **Producción necesita un proveedor de teselas**. Sin URL configurada, no hay mapa.
- **Qué dibuja**, en «Recorrido», bajo el árbol de lotes: las paradas de cada lote en el orden del historial (dos pasos seguidos en el mismo municipio son una parada), una línea entre ellas, la última resaltada, el encuadre de todas y la lista de paradas debajo.
- **Qué no hace:** no sustituye a la línea de tiempo. Sin ninguna parada con punto, el mapa no aparece. Sin conexión, las teselas no cargan y se avisa; las paradas se ven igual. El `trackingCode` sigue solo en memoria (ADR-043 §0); las peticiones de teselas no llevan nada del seguimiento.

## Alternativas descartadas

| Alternativa | Por qué no |
|---|---|
| Coordenadas en el backend | El backend es de otro compañero y ya da la zona sellada; la app se adapta a él |
| Geocodificar el texto de la zona con un servicio externo | Poco fiable y envía las zonas del recorrido a un tercero |
| GPS del teléfono del empleado | Dato personal; pide permiso, consentimiento y borrado |
| Waze | Sin mapa embebible para dibujar un recorrido propio |
| Google Maps | Necesita clave y facturación, y otra dependencia de Google |

## Consecuencias

- La app ocupa unos 48 KB más por la tabla de zonas.
- Los pasos antiguos con texto libre no salen en el mapa, aunque sí en la línea de tiempo.
- Riesgo aceptado: el centro del municipio no es el lugar del paso; el mapa lo dice («la zona pública de cada paso, nunca el lugar exacto»).
- Tests: la tabla se lee y descarta lo inválido; las paradas se ordenan, omiten los pasos sin punto y unen los repetidos; sin ningún punto o sin teselas no hay mapa; sin conexión, aviso; la atribución siempre se ve.
