"""Genera assets/map/zonas.json: el punto de cada zona pública DIVIPOLA para el mapa del recorrido (ADR-052).

Uso: python3 -I scripts/generar_zonas_mapa.py <divipola.json del backend> <municipios del DANE con coordenadas>

- divipola.json: el catálogo que usa el backend (Donaciones, app/src/main/resources/divipola/divipola.json), el mismo
  de GET /public/locations. De él sale el texto de la zona exactamente como lo sella el backend (SealedZone.of):
  "MUNICIPIO, DEPARTAMENTO", o solo el municipio si los dos nombres son iguales.
- Las coordenadas: DIVIPOLA del DANE publicada en datos.gov.co (conjunto gdxc-w37w, campos latitud y longitud con coma
  decimal), unidas por código de municipio. Una zona sin coordenadas se omite: nunca se inventa un punto.
"""
import json
import sys


def main(catalog_path, dane_path, out_path):
    catalog = json.load(open(catalog_path, encoding="utf-8"))
    dane = json.load(open(dane_path, encoding="utf-8"))
    coords = {}
    for row in dane:
        try:
            lat = float(row["latitud"].replace(",", "."))
            lon = float(row["longitud"].replace(",", "."))
        except (KeyError, ValueError):
            continue
        if -5 <= lat <= 14 and -82 <= lon <= -66:  # dentro de Colombia
            coords[row["cod_mpio"]] = (round(lat, 5), round(lon, 5))
    zones, missing = {}, []
    for d in catalog["departments"]:
        for m in d["municipalities"]:
            name = m["name"] if m["name"] == d["name"] else f'{m["name"]}, {d["name"]}'
            if m["code"] in coords:
                zones[name] = list(coords[m["code"]])
            else:
                missing.append(f'{m["code"]} {name}')
    out = {
        "catalogVersion": catalog["catalogVersion"],
        "source": "DANE, DIVIPOLA en datos.gov.co (gdxc-w37w): centro de cada municipio",
        "zones": dict(sorted(zones.items())),
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
        f.write("\n")
    print(f"{len(zones)} zonas con punto; {len(missing)} sin coordenadas")
    for x in missing:
        print("  sin coordenadas:", x)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "assets/map/zonas.json")
