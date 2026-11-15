#!/usr/bin/env python3
"""Iconos de PaxFide a partir del logo oficial (Documentos/marca/paxfide-logo-original.webp).

Recorta el emblema (sin el texto), le quita el fondo blanco y escribe todos los iconos del repositorio:
    python3 scripts/marca/generar-iconos.py web     (desde la raíz de PaxFide)
    python3 scripts/marca/generar-iconos.py movil   (desde la raíz de PaxFide_Mv)
Necesita Pillow y NumPy. Si cambia el logo, se sustituye el original y se vuelve a ejecutar.
"""
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = pathlib.Path.cwd()
ORIGINAL = ROOT / "Documentos/marca/paxfide-logo-original.webp"
# Caja del emblema dentro del logo de 1254 x 1254 (medida con el contorno de lo que no es blanco: 332,78,918,743)
EMBLEM_BOX = (322, 68, 928, 753)
WHITE = (255, 255, 255)


def emblem() -> Image.Image:
    """Emblema cuadrado de 1024 px, fondo transparente, colores sin alterar."""
    src = np.asarray(Image.open(ORIGINAL).convert("RGB").crop(EMBLEM_BOX), dtype=np.float64)
    d = np.max((255.0 - src) / 255.0, axis=2)
    # opacos y con su color exacto los píxeles con color (d >= 0.28); semitransparentes los casi blancos (bordes
    # suavizados, aro claro); transparente el ruido de compresión del fondo
    a = np.clip(d / 0.28, 0, 1)
    a = np.where(d < 0.03, 0.0, a)
    rgb = np.clip((src - 255.0 * (1 - a[..., None])) / np.maximum(a, 1e-6)[..., None], 0, 255)
    e = Image.fromarray(np.dstack([rgb, a * 255]).astype(np.uint8), "RGBA")
    side = max(e.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(e, ((side - e.width) // 2, (side - e.height) // 2))
    return sq.resize((1024, 1024), Image.LANCZOS)


EMB = None


def icon(size, scale=1.0, bg=None, plate=None, mode="RGBA"):
    """Emblema a `scale` del lado, centrado. `bg`: fondo opaco; `plate`: (fracción, radio) de una placa blanca."""
    canvas = Image.new("RGBA", (size, size), (bg + (255,)) if bg else (0, 0, 0, 0))
    if plate:
        frac, radius = plate
        p = int(round(size * frac))
        off = (size - p) // 2
        ImageDraw.Draw(canvas).rounded_rectangle((off, off, off + p - 1, off + p - 1), radius=int(p * radius),
                                                fill=WHITE + (255,))
        scale = frac * scale
    s = max(1, int(round(size * scale)))
    canvas.alpha_composite(EMB.resize((s, s), Image.LANCZOS), ((size - s) // 2, (size - s) // 2))
    return canvas.convert(mode) if mode != "RGBA" else canvas


def save(img, rel):
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    print(f"{rel}  {img.size[0]}x{img.size[1]} {img.mode}")


def ico(rel, sizes):
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    icon(256).save(path, format="ICO", sizes=[(s, s) for s in sizes])
    print(f"{rel}  ICO {sizes}")


def web():
    save(icon(192), "public/marca/paxfide-emblema.png")           # la marca dentro de la app (BrandMark)
    ico("src/app/favicon.ico", [16, 32, 48])                        # favicon (convención de Next.js)
    save(icon(512), "src/app/icon.png")                             # <link rel="icon"> en PNG
    save(icon(180, 0.84, bg=WHITE, mode="RGB"), "src/app/apple-icon.png")  # iOS no admite transparencia
    save(icon(192, 0.84, bg=WHITE, mode="RGB"), "public/marca/icon-192.png")
    save(icon(512, 0.84, bg=WHITE, mode="RGB"), "public/marca/icon-512.png")
    save(icon(512, 0.62, bg=WHITE, mode="RGB"), "public/marca/icon-maskable-512.png")  # dentro de la zona segura


def movil():
    # dentro de la app (resolución 1x, 2x y 3x para Image.asset)
    # (PaxLogo llega a 120 dp: 128/256/384 px lo cubren nítido en 1x, 2x y 3x)
    save(icon(128), "assets/marca/paxfide_emblema.png")
    save(icon(256), "assets/marca/2.0x/paxfide_emblema.png")
    save(icon(384), "assets/marca/3.0x/paxfide_emblema.png")
    # Android: icono clásico y adaptativo (Android 8+), con el emblema dentro de la zona segura de 66 dp
    for density, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        save(icon(px, 0.86, bg=WHITE, mode="RGB"), f"android/app/src/main/res/mipmap-{density}/ic_launcher.png")
        fg = px * 108 // 48
        save(icon(fg, 0.60), f"android/app/src/main/res/mipmap-{density}/ic_launcher_foreground.png")
    # iOS: opacos, sin transparencia (lo exige el App Store)
    for name, px in {"20x20@1x": 20, "20x20@2x": 40, "20x20@3x": 60, "29x29@1x": 29, "29x29@2x": 58,
                     "29x29@3x": 87, "40x40@1x": 40, "40x40@2x": 80, "40x40@3x": 120, "60x60@2x": 120,
                     "60x60@3x": 180, "76x76@1x": 76, "76x76@2x": 152, "83.5x83.5@2x": 167,
                     "1024x1024@1x": 1024}.items():
        save(icon(px, 0.84, bg=WHITE, mode="RGB"), f"ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-{name}.png")
    # macOS: placa blanca redondeada (plantilla de macOS: 824/1024, radio 22 %)
    for px in (16, 32, 64, 128, 256, 512, 1024):
        save(icon(px, 0.86, plate=(824 / 1024, 0.22)), f"macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{px}.png")
    # web de Flutter
    save(icon(32), "web/favicon.png")
    save(icon(192, 0.84, bg=WHITE, mode="RGB"), "web/icons/Icon-192.png")
    save(icon(512, 0.84, bg=WHITE, mode="RGB"), "web/icons/Icon-512.png")
    save(icon(192, 0.62, bg=WHITE), "web/icons/Icon-maskable-192.png")
    save(icon(512, 0.62, bg=WHITE), "web/icons/Icon-maskable-512.png")
    # Windows
    ico("windows/runner/resources/app_icon.ico", [16, 32, 48, 256])


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else ""
    if target not in ("web", "movil"):
        sys.exit("uso: generar-iconos.py web|movil")
    EMB = emblem()
    {"web": web, "movil": movil}[target]()
